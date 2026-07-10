import SwiftUI

enum CardLang: String, CaseIterable {
    case english, hebrew
    var speechCode: String {
        switch self { case .english: return "en-US"; case .hebrew: return "he-IL" }
    }
    var isRTL: Bool { self == .hebrew }
    init(code: String) {
        self = code == "he" ? .hebrew : .english
    }
}

// MARK: - Deck builder
/// Builds a session deck with no repeats across sessions and strict level matching:
/// review-flagged bank words first, then unseen bank words at the user's level,
/// then unseen pack words for that level. Seen history resets when the pool runs dry.
enum FlashcardDeckBuilder {
    private static func seenKey(_ level: String) -> String { "flashSeen_\(level)" }

    static func build(bank: [Word], level: String, size: Int = 20) -> [Word] {
        let defaults = UserDefaults.standard
        var seen = Set(defaults.stringArray(forKey: seenKey(level)) ?? [])

        var pool: [Word] = []
        var used = Set<String>()
        func add(_ w: Word) {
            let key = w.word.lowercased()
            guard !used.contains(key) else { return }
            used.insert(key); pool.append(w)
        }

        // 1. Bank words flagged for review — always first
        bank.filter(\.needsReview).shuffled().forEach(add)
        // 2. Unseen bank words at the user's level
        bank.filter { $0.level == level && !$0.needsReview && !seen.contains($0.word.lowercased()) }
            .shuffled().forEach(add)
        // 3. Unseen pack words, strictly this level
        let pack = VocabularyService.shared.words(for: level)
        var unseenPack = pack.filter { !seen.contains($0.word.lowercased()) }
        if unseenPack.count + pool.count < size {
            // Pool exhausted — start a fresh cycle for this level
            seen = []
            defaults.removeObject(forKey: seenKey(level))
            unseenPack = pack
        }
        unseenPack.shuffled().forEach(add)

        return Array(pool.prefix(size))
    }

    static func markSeen(_ word: Word, level: String) {
        let key = seenKey(level)
        var seen = UserDefaults.standard.stringArray(forKey: key) ?? []
        let t = word.word.lowercased()
        if !seen.contains(t) { seen.append(t); UserDefaults.standard.set(seen, forKey: key) }
    }
}

struct FlashcardsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let words: [Word]
    var level: String = "intermediate"

    @State private var deck: [Word] = []
    @State private var index = 0
    @State private var knownCount = 0
    @State private var unknownCount = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var finished = false

    // Auto-collection of missed words
    @State private var addedToBank = 0
    @State private var markedForReview = 0

    @AppStorage("targetLanguage") private var targetLang = "en"
    @AppStorage("nativeLanguage") private var nativeLang = "he"
    private var frontLang: CardLang { CardLang(code: targetLang) }
    private var backLang: CardLang { CardLang(code: nativeLang) }

    @State private var cardScale: CGFloat = 1
    @State private var cardAppear = false

    private let sessionSize = 20
    private var progress: Double { deck.isEmpty ? 0 : Double(index) / Double(deck.count) }

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea()
            if finished { resultView.transition(.scale(scale: 0.9).combined(with: .opacity)) }
            else { playView }
        }
        .onAppear(perform: setup)
    }

    private var playView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary) }
                Spacer()
                Text("\(min(index + 1, deck.count)) / \(deck.count)").font(.headline)
                    .foregroundStyle(LinearGradient.crystalShort).contentTransition(.numericText())
                Spacer()
                Image(systemName: "xmark.circle.fill").font(.title2).opacity(0)
            }
            .padding(.horizontal).padding(.top, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(LinearGradient.crystal).frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8).padding(.horizontal).padding(.top, 14)

            HStack(spacing: 20) {
                Label("\(unknownCount)", systemImage: "xmark.circle.fill").foregroundColor(.red).contentTransition(.numericText())
                Spacer()
                Label("\(knownCount)", systemImage: "checkmark.circle.fill").foregroundColor(.crystalMint).contentTransition(.numericText())
            }
            .font(.subheadline.bold()).padding(.horizontal, 36).padding(.top, 14)

            Spacer()

            if let word = deck[safe: index] {
                FlashCard(word: word, isFlipped: isFlipped, frontLang: frontLang, backLang: backLang)
                    .frame(width: 300, height: 200)
                    .scaleEffect(cardScale * (cardAppear ? 1 : 0.85)).opacity(cardAppear ? 1 : 0)
                    .offset(dragOffset).rotationEffect(.degrees(Double(dragOffset.width / 20)))
                    .overlay(swipeBadge)
                    .onTapGesture(count: 2) { withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { isFlipped.toggle() } }
                    .gesture(DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                            cardScale = 1 - min(abs(value.translation.width) / 2000, 0.05)
                        }
                        .onEnded { handleSwipeEnd($0.translation.width) })
            }

            Spacer()
            Text("Double-tap to flip · Swipe to answer").font(.caption2).foregroundColor(.secondary).padding(.bottom, 28)
        }
    }

    private var swipeBadge: some View {
        ZStack {
            if dragOffset.width > 30 {
                badge(text: "GOT IT", color: .crystalMint, rotation: -14, align: .topLeading).opacity(min(Double(dragOffset.width) / 110, 1))
            } else if dragOffset.width < -30 {
                badge(text: "AGAIN", color: .red, rotation: 14, align: .topTrailing).opacity(min(Double(-dragOffset.width) / 110, 1))
            }
        }
    }

    private func badge(text: String, color: Color, rotation: Double, align: Alignment) -> some View {
        Text(text).font(.system(size: 24, weight: .heavy)).foregroundColor(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(rotation)).padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
    }

    private var resultView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 72)).foregroundColor(.crystalMint).scaleEffect(cardAppear ? 1 : 0.5)
            CrystalText(text: "All Done!", font: .largeTitle.bold())
            if knownCount > 0 {
                Text("+\(knownCount * 2) XP").font(.title3.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
                    .scaleEffect(cardAppear ? 1 : 0.4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55), value: cardAppear)
            }
            HStack(spacing: 28) {
                resultStat(value: knownCount, label: "Knew", color: .crystalMint)
                resultStat(value: unknownCount, label: "To review", color: .red)
            }
            if addedToBank > 0 || markedForReview > 0 {
                VStack(spacing: 4) {
                    if addedToBank > 0 {
                        Label("\(addedToBank) new word\(addedToBank == 1 ? "" : "s") added to your Word Bank",
                              systemImage: "plus.circle.fill")
                            .font(.caption.bold()).foregroundColor(.crystalMint)
                    }
                    if markedForReview > 0 {
                        Label("\(markedForReview) word\(markedForReview == 1 ? "" : "s") marked for review",
                              systemImage: "arrow.clockwise.circle.fill")
                            .font(.caption.bold()).foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.ultraThinMaterial).cornerRadius(12)
            }
            VStack(spacing: 12) {
                Button(action: setup) {
                    Text("Study Again").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 52)
                        .background(LinearGradient.crystal).cornerRadius(16)
                }
                Button { dismiss() } label: {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).frame(height: 52).background(.ultraThinMaterial).cornerRadius(16)
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func resultStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 40, weight: .bold)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(width: 110).padding(.vertical, 16).background(.ultraThinMaterial).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(color.opacity(0.3), lineWidth: 1))
    }

    private func setup() {
        // The deck arrives pre-prioritized from FlashcardDeckBuilder — keep its order
        deck = Array(words.prefix(sessionSize))
        index = 0; knownCount = 0; unknownCount = 0; isFlipped = false; dragOffset = .zero; cardScale = 1
        addedToBank = 0; markedForReview = 0
        finished = deck.isEmpty
        cardAppear = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { cardAppear = true }
    }

    private func handleSwipeEnd(_ width: CGFloat) {
        if width > 100 {
            knownCount += 1
            if let w = deck[safe: index] { FlashcardDeckBuilder.markSeen(w, level: level) }
            advance(toRight: true)
        }
        else if width < -100 {
            unknownCount += 1
            if let missed = deck[safe: index] {
                FlashcardDeckBuilder.markSeen(missed, level: level)
                recordUnknown(missed)
            }
            advance(toRight: false)
        }
        else { withAnimation(.spring()) { dragOffset = .zero; cardScale = 1 } }
    }

    /// A missed word is automatically saved: pack words are added to the
    /// Word Bank (and AI-enriched), bank words are flagged for review.
    private func recordUnknown(_ word: Word) {
        guard let uid = authVM.user?.uid else { return }
        if word.id != nil {
            // Already in the bank — just flag it for review
            if !word.needsReview {
                markedForReview += 1
                Task { await wordBankVM.toggleNeedsReview(word, uid: uid) }
            }
        } else if !wordBankVM.words.contains(where: { $0.word.lowercased() == word.word.lowercased() }) {
            addedToBank += 1
            var newWord = word
            newWord.needsReview = true
            newWord.context = "Missed in Flashcards"
            newWord.tags = ["Review"]
            Task { await wordBankVM.addWord(newWord, uid: uid) }
        }
    }

    private func advance(toRight: Bool) {
        withAnimation(.easeOut(duration: 0.28)) {
            dragOffset = CGSize(width: toRight ? 700 : -700, height: 40); cardAppear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isFlipped = false; dragOffset = .zero; cardScale = 1
            if index < deck.count - 1 {
                index += 1
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { cardAppear = true }
            } else {
                if knownCount > 0, let uid = authVM.user?.uid {
                    Task { try? await RealtimeDatabaseService.shared.addXP(knownCount * 2, for: uid) }
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { finished = true }
                cardAppear = true
            }
        }
    }
}

private struct FlashCard: View {
    let word: Word
    let isFlipped: Bool
    let frontLang: CardLang
    let backLang: CardLang
    @Environment(\.colorScheme) private var scheme

    private func text(for lang: CardLang) -> String {
        switch lang {
        case .english: return word.word
        case .hebrew:  return word.translation.isEmpty ? (VocabularyService.shared.translation(for: word.word)?.hebrew ?? "-") : word.translation
        }
    }

    var body: some View {
        ZStack {
            cardFront.opacity(isFlipped ? 0 : 1)
            cardBack.opacity(isFlipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.clear.background(.ultraThinMaterial)
                LinearGradient(
                    stops: [
                        .init(color: Color.crystalBlue.opacity(0.18), location: 0),
                        .init(color: Color.crystalMint.opacity(0.08), location: 0.55),
                        .init(color: Color.crystalGold.opacity(0.05), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal, lineWidth: 1.5))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(scheme == .dark ? 0.07 : 0.28), .clear],
                startPoint: .top, endPoint: .init(x: 0.5, y: 0.45)
            )
            .allowsHitTesting(false).clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .shadow(color: Color.crystalBlue.opacity(0.22), radius: 28, y: 14)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private var cardFront: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.caption2).foregroundStyle(LinearGradient.crystalShort)
                    Text("Word").font(.caption2.bold()).foregroundColor(.secondary)
                }
                Spacer()
                if !word.level.isEmpty {
                    Text(word.level.capitalized).font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.crystalBlue.opacity(0.15))
                        .foregroundColor(.crystalBlue).cornerRadius(5)
                }
            }
            .padding(.horizontal, 16).padding(.top, 12)

            Spacer()

            HStack(spacing: 12) {
                Text(text(for: frontLang))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(LinearGradient.crystal)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .environment(\.layoutDirection, frontLang.isRTL ? .rightToLeft : .leftToRight)
                SpeakButton(text: text(for: frontLang), language: frontLang.speechCode)
            }
            .padding(.horizontal, 16)

            Spacer()

            if !word.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(word.tags.prefix(2), id: \.self) { tag in
                        Text(tag).font(.caption2.bold())
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.crystalMint.opacity(0.15))
                            .foregroundColor(.crystalMint).cornerRadius(5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                Spacer().frame(height: 12)
            }
        }
    }

    private var cardBack: some View {
        VStack(spacing: 0) {
            HStack {
                Text(text(for: frontLang)).font(.caption.bold()).foregroundColor(.secondary)
                    .environment(\.layoutDirection, frontLang.isRTL ? .rightToLeft : .leftToRight)
                Spacer()
                Text("Translation").font(.caption2.bold()).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.top, 12)

            Spacer()

            HStack(spacing: 12) {
                Text(text(for: backLang))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient.crystal)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .environment(\.layoutDirection, backLang.isRTL ? .rightToLeft : .leftToRight)
                SpeakButton(text: text(for: backLang), language: backLang.speechCode)
            }
            .padding(.horizontal, 16)

            Spacer()

            if !word.context.isEmpty {
                Text("« \(word.context) »")
                    .font(.caption2).italic().foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.tail)
                    .padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                Spacer().frame(height: 12)
            }
        }
    }
}

#Preview("Light") { FlashcardsView(words: [.sample]).environmentObject(AuthViewModel()).environmentObject(WordBankViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { FlashcardsView(words: [.sample]).environmentObject(AuthViewModel()).environmentObject(WordBankViewModel()).preferredColorScheme(.dark) }
