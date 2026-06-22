import SwiftUI

enum CardLang: String, CaseIterable {
    case english, hebrew, french
    var speechCode: String {
        switch self { case .english: return "en-US"; case .hebrew: return "he-IL"; case .french: return "fr-FR" }
    }
    var isRTL: Bool { self == .hebrew }
    init(code: String) {
        switch code { case "he": self = .hebrew; case "fr": self = .french; default: self = .english }
    }
}

struct FlashcardsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let words: [Word]

    @State private var deck: [Word] = []
    @State private var index = 0
    @State private var knownCount = 0
    @State private var unknownCount = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var finished = false

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
            Color(.systemGroupedBackground).ignoresSafeArea()
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
                    .frame(maxWidth: 320)
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
            HStack(spacing: 28) {
                resultStat(value: knownCount, label: "Knew", color: .crystalMint)
                resultStat(value: unknownCount, label: "To review", color: .red)
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
        deck = Array(words.shuffled().prefix(sessionSize))
        index = 0; knownCount = 0; unknownCount = 0; isFlipped = false; dragOffset = .zero; cardScale = 1
        finished = deck.isEmpty
        cardAppear = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { cardAppear = true }
    }

    private func handleSwipeEnd(_ width: CGFloat) {
        if width > 100 { knownCount += 1; advance(toRight: true) }
        else if width < -100 { unknownCount += 1; advance(toRight: false) }
        else { withAnimation(.spring()) { dragOffset = .zero; cardScale = 1 } }
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

    private func text(for lang: CardLang) -> String {
        switch lang {
        case .english: return word.word
        case .hebrew:  return word.translation.isEmpty ? (VocabularyService.shared.translation(for: word.word)?.hebrew ?? "—") : word.translation
        case .french:  return word.french.isEmpty ? (VocabularyService.shared.translation(for: word.word)?.french ?? "—") : word.french
        }
    }

    var body: some View {
        ZStack {
            cardFront.opacity(isFlipped ? 0 : 1)
            cardBack.opacity(isFlipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 300)
        .background(
            ZStack {
                Color.white.opacity(0.05)
                LinearGradient(colors: [Color.crystalBlue.opacity(0.10), Color.crystalMint.opacity(0.05), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .background(.ultraThinMaterial)
        )
        .cornerRadius(26)
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(LinearGradient.crystal, lineWidth: 2))
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center)
                .frame(height: 120).allowsHitTesting(false).clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .shadow(color: Color.crystalBlue.opacity(0.18), radius: 16, y: 10)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private var cardFront: some View {
        VStack(spacing: 14) {
            Image(systemName: "character.book.closed.fill").font(.title2).foregroundStyle(LinearGradient.crystalShort)
            Text(text(for: frontLang)).font(.system(size: 32, weight: .bold)).foregroundStyle(LinearGradient.crystal)
                .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                .environment(\.layoutDirection, frontLang.isRTL ? .rightToLeft : .leftToRight)
            SpeakButton(text: text(for: frontLang), language: frontLang.speechCode)
            if !word.tags.isEmpty { Text(word.tags.joined(separator: " · ")).font(.caption.bold()).foregroundColor(.crystalBlue) }
        }
        .padding(24)
    }

    private var cardBack: some View {
        VStack(spacing: 18) {
            Text(text(for: frontLang)).font(.subheadline.bold()).foregroundColor(.secondary)
                .environment(\.layoutDirection, frontLang.isRTL ? .rightToLeft : .leftToRight)
            HStack(spacing: 8) {
                Text(text(for: backLang)).font(.system(size: 28, weight: .bold)).foregroundStyle(LinearGradient.crystal)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                    .environment(\.layoutDirection, backLang.isRTL ? .rightToLeft : .leftToRight)
                SpeakButton(text: text(for: backLang), language: backLang.speechCode, compact: true)
            }
        }
        .padding(24)
    }
}

private struct SpeakButton: View {
    let text: String
    var language: String = "en-US"
    var compact: Bool = false
    @State private var animate = false
    var body: some View {
        Button {
            SpeechService.shared.speak(text, accent: language)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { animate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { animate = false }
        } label: {
            Image(systemName: "speaker.wave.2.fill").font(compact ? .caption : .subheadline.bold())
                .foregroundStyle(LinearGradient.crystalShort).padding(compact ? 6 : 10)
                .background(Color.crystalBlue.opacity(0.12)).clipShape(Circle()).scaleEffect(animate ? 1.25 : 1)
        }
        .buttonStyle(.plain)
    }
}
