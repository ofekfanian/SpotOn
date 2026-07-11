import SwiftUI

/// The daily 20-word quiz. Pops up automatically once per day when the app
/// opens (gated by MainTabView). Words are dealt by FlashcardDeckBuilder so
/// they share the same freshness history as the flashcards — always new words.
struct DailyQuizView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let level: String

    private struct Question {
        let word: Word
        let options: [String]
        let correctIndex: Int
    }

    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var score = 0
    @State private var selected: Int? = nil
    @State private var finished = false

    private var progress: Double { questions.isEmpty ? 0 : Double(index) / Double(questions.count) }

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
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill").foregroundColor(.crystalGold)
                    CrystalText(text: "Daily Quiz", font: .headline)
                }
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

            HStack {
                Text("\(min(index + 1, questions.count)) / \(questions.count)")
                    .font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
                Text("\(score) correct").font(.caption.bold()).foregroundColor(.crystalMint)
            }
            .padding(.horizontal).padding(.top, 10)

            Spacer()

            if let q = questions[safe: index] {
                VStack(spacing: 22) {
                    Text("What does this mean?").font(.headline).foregroundColor(.secondary)
                    Text(q.word.word)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(LinearGradient.crystal)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    VStack(spacing: 12) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                            Button { answer(idx, q: q) } label: {
                                ZStack {
                                    Text(option).font(.body.bold()).multilineTextAlignment(.center)
                                    HStack {
                                        Spacer()
                                        if selected != nil && idx == q.correctIndex {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                        } else if selected == idx {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding().frame(maxWidth: .infinity)
                                .background(optionColor(idx, q: q))
                                .foregroundColor(.primary).cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.crystalBlue.opacity(0.2), lineWidth: 1))
                            }
                            .disabled(selected != nil)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    private var resultView: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: score >= questions.count * 7 / 10 ? "sun.max.fill" : "sunrise.fill")
                .font(.system(size: 68)).foregroundStyle(LinearGradient.crystal)
            CrystalText(text: "Daily Quiz Complete!", font: .title.bold())
            Text("\(score) / \(questions.count) correct").font(.title3).foregroundColor(.secondary)
            if score > 0 {
                Text("+\(score * 5) XP").font(.title3.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
            }
            Button { dismiss() } label: {
                Text("Done").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient.crystalShort).cornerRadius(17)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Logic

    private func setup() {
        let pool = VocabularyService.shared.words(for: level)
        let translations = pool.map(\.translation).filter { !$0.isEmpty }
        guard translations.count >= 4 else { dismiss(); return }

        let dealt = FlashcardDeckBuilder.build(bank: wordBankVM.words, level: level, size: 20)
            .filter { !$0.translation.isEmpty }
        questions = dealt.map { word in
            var options = translations.filter { $0 != word.translation }.shuffled().prefix(3) + [word.translation]
            options.shuffle()
            return Question(word: word,
                            options: Array(options),
                            correctIndex: options.firstIndex(of: word.translation) ?? 0)
        }
        if questions.isEmpty { dismiss() }
        index = 0; score = 0; selected = nil; finished = false
    }

    private func answer(_ idx: Int, q: Question) {
        guard selected == nil else { return }
        selected = idx
        if idx == q.correctIndex { score += 1; SoundService.playCorrect() } else { SoundService.playWrong() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if index < questions.count - 1 {
                index += 1; selected = nil
            } else {
                if score > 0, let uid = authVM.user?.uid {
                    Task { try? await RealtimeDatabaseService.shared.addXP(score * 5, for: uid) }
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { finished = true }
            }
        }
    }

    private func optionColor(_ idx: Int, q: Question) -> Color {
        guard selected != nil else { return Color(.secondarySystemBackground) }
        if idx == q.correctIndex { return Color.green.opacity(0.18) }
        if idx == selected { return Color.red.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }
}

#Preview("Light") {
    DailyQuizView(level: "beginner")
        .environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.light)
}
