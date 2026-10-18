import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Quiz types

enum QuizType {
    case multipleChoice(question: String, options: [String], correctIndex: Int)
    case fillBlank(before: String, after: String, answer: String)
}

struct QuizItem: Identifiable {
    let id = UUID()
    let wordText: String
    let hebrewHint: String
    let type: QuizType
}

// MARK: - ViewModel

@MainActor
final class ReadingPathwayViewModel: ObservableObject {

    // MARK: Published

    @Published var passages: [ReadingPassage] = []
    @Published var isSpeaking = false
    @Published var isPaused   = false

    // MARK: Private

    private let synthesizer = AVSpeechSynthesizer()
    // Strong reference — AVSpeechSynthesizer.delegate is weak, so we must own the delegate
    // or it deallocates instantly and didFinish/didCancel never fire.
    private var delegateHolder: TTSDelegate?

    // MARK: - Load

    func loadPassages(context: ModelContext) {
        let desc = FetchDescriptor<ReadingPassage>(
            sortBy: [SortDescriptor(\.level), SortDescriptor(\.orderIndex)]
        )
        passages = (try? context.fetch(desc)) ?? []
    }

    // MARK: - Progress

    func markCompleted(_ passage: ReadingPassage, context: ModelContext) {
        guard !passage.isCompleted else { return }
        passage.isCompleted = true
        passage.completedAt = Date()
        try? context.save()
        loadPassages(context: context)
    }

    func markWordSeen(_ word: PassageWord, context: ModelContext) {
        guard !word.isSeen else { return }
        word.isSeen = true
        try? context.save()
    }

    func markWordSaved(_ word: PassageWord, context: ModelContext) {
        word.isSaved = true
        try? context.save()
    }

    /// Cross-references the passage's target words against the user's Firestore word bank.
    /// Any word already in the bank is marked as seen (removing the red highlight)
    /// and its `isSaved` flag is set to prevent the "Save" button from showing.
    func autoMarkKnownWords(passage: ReadingPassage, bankWords: [Word], context: ModelContext) {
        let bankSet = Set(bankWords.map { $0.word.lowercased() })
        var changed = false
        for pw in passage.words where !pw.isSeen {
            if bankSet.contains(pw.text.lowercased()) {
                pw.isSeen  = true
                pw.isSaved = true
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice  = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate   = 0.44
        utterance.pitchMultiplier = 1.05

        let delegate = TTSDelegate { [weak self] in
            self?.isSpeaking = false
            self?.isPaused   = false
        }
        delegateHolder      = delegate
        synthesizer.delegate = delegate

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused   = false
    }

    func pauseOrResume() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        } else if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused   = false
    }

    // MARK: - Quiz generation

    func generateQuiz(for passage: ReadingPassage) -> [QuizItem] {
        let words = passage.words.shuffled()
        guard words.count >= 2 else { return [] }

        var items: [QuizItem] = []

        for word in words {
            // Alternate between question types
            if items.count.isMultiple(of: 2) {
                if let mc = makeMultipleChoice(word: word, allWords: words) {
                    items.append(mc)
                }
            } else {
                if let fb = makeFillBlank(word: word, content: passage.content) {
                    items.append(fb)
                }
            }
        }
        return Array(items.prefix(8))
    }

    // MARK: - Quiz helpers

    private func makeMultipleChoice(word: PassageWord, allWords: [PassageWord]) -> QuizItem? {
        let correct = word.hebrewTranslation
        guard !correct.isEmpty else { return nil }
        let distractors = Array(Set(allWords
            .filter { $0.text != word.text && !$0.hebrewTranslation.isEmpty && $0.hebrewTranslation != correct }
            .map(\.hebrewTranslation)))
            .shuffled()
            .prefix(3)
        guard distractors.count == 3 else { return nil }

        var options = Array(distractors) + [correct]
        options.shuffle()
        let correctIndex = options.firstIndex(of: correct) ?? 0

        return QuizItem(
            wordText: word.text,
            hebrewHint: correct,
            type: .multipleChoice(
                question: "What is the Hebrew translation of '\(word.text)'?",
                options: options,
                correctIndex: correctIndex
            )
        )
    }

    private func makeFillBlank(word: PassageWord, content: String) -> QuizItem? {
        // Find the sentence containing the word
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Whole-word match only: "art" must not be found inside "start".
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word.text))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        func match(in s: String) -> Range<String.Index>? {
            regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)).flatMap { Range($0.range, in: s) }
        }
        guard let sentence = sentences.first(where: { match(in: $0) != nil }),
              let range = match(in: sentence) else { return nil }

        // Replace the first occurrence with ___
        let before = String(sentence[sentence.startIndex..<range.lowerBound])
        let after  = String(sentence[range.upperBound...])

        return QuizItem(
            wordText: word.text,
            hebrewHint: word.hebrewTranslation,
            type: .fillBlank(before: before, after: after, answer: word.text)
        )
    }
}

// MARK: - TTS Delegate

private final class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish() }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish() }
    }
}
