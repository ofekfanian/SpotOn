import SwiftUI

// MARK: - Daily topic service

/// Serves the topic of the day from the bundled daily_topics.json.
/// Rotates deterministically: a new topic every 24 hours, cycling
/// through all 20 topics before repeating.
final class DailyTopicService {
    static let shared = DailyTopicService()
    private init() {}

    struct Topic: Decodable {
        let name: String
        let icon: String
        let words: [TopicWord]
    }
    struct TopicWord: Decodable {
        let en: String
        let he: String
    }
    private struct File: Decodable { let topics: [Topic] }

    private var topics: [Topic] = []
    private var loaded = false

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let url = Bundle.main.url(forResource: "daily_topics", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else { return }
        topics = decoded.topics
    }

    func todayTopic() -> Topic? {
        loadIfNeeded()
        guard !topics.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return topics[day % topics.count]
    }
}

// MARK: - Daily quiz

/// The daily quiz: 15 words on a single interesting topic that changes
/// every day (computer science today, job interviews tomorrow...).
/// Pops up automatically once per day, gated by MainTabView.
struct DailyQuizView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let level: String

    private struct Question {
        let word: DailyTopicService.TopicWord
        let options: [String]
        let correctIndex: Int
    }

    @State private var topic: DailyTopicService.Topic?
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
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill").foregroundColor(.crystalGold)
                CrystalText(text: "Daily Quiz", font: .headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)

            // Topic banner — today's theme
            if let topic {
                HStack(spacing: 8) {
                    Image(systemName: topic.icon)
                        .font(.subheadline)
                        .foregroundStyle(LinearGradient.crystalShort)
                    Text("Today's topic: \(topic.name)")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(.ultraThinMaterial).cornerRadius(20)
                .overlay(Capsule().strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1))
                .padding(.top, 14)
            }

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
                    Text(q.word.en)
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
            Image(systemName: topic?.icon ?? "sun.max.fill")
                .font(.system(size: 68)).foregroundStyle(LinearGradient.crystal)
            CrystalText(text: "Daily Quiz Complete!", font: .title.bold())
            if let topic {
                Text(topic.name).font(.subheadline.bold()).foregroundColor(.crystalMint)
            }
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
        guard let today = DailyTopicService.shared.todayTopic(), today.words.count >= 4 else {
            dismiss(); return
        }
        topic = today
        let allTranslations = today.words.map(\.he)
        questions = today.words.shuffled().map { word in
            var options = allTranslations.filter { $0 != word.he }.shuffled().prefix(3) + [word.he]
            options.shuffle()
            return Question(word: word,
                            options: Array(options),
                            correctIndex: options.firstIndex(of: word.he) ?? 0)
        }
        index = 0; score = 0; selected = nil; finished = false
    }

    /// A word answered correctly joins the bank as Mastered,
    /// exactly like a known flashcard — the Words counter grows.
    private func recordKnown(_ word: DailyTopicService.TopicWord) {
        guard let uid = authVM.user?.uid else { return }
        guard !wordBankVM.words.contains(where: { $0.word.lowercased() == word.en.lowercased() }) else { return }
        var newWord = Word(word: word.en.capitalized, translation: word.he,
                           definition: "", context: "Daily Quiz: \(topic?.name ?? "")",
                           tags: ["Daily Quiz"], level: level)
        newWord.isMastered = true
        newWord.masteredAt = Date()
        Task { await wordBankVM.addWord(newWord, uid: uid, enrich: false) }
    }

    private func answer(_ idx: Int, q: Question) {
        guard selected == nil else { return }
        selected = idx
        if idx == q.correctIndex {
            score += 1; SoundService.playCorrect()
            recordKnown(q.word)
        } else { SoundService.playWrong() }
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
