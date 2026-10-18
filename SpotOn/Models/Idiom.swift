import Foundation

struct Idiom: Identifiable, Codable {
    var id: String { text }
    var text: String
    var definition: String
    var example: String
    var hebrew: String
    var level: String

    static let sample = Idiom(
        text: "Hit the nail on the head",
        definition: "To be exactly right about something",
        example: "You really hit the nail on the head with that suggestion.",
        hebrew: "קלעת בול, פגעת בדיוק",
        level: "intermediate"
    )
}

/// Serves the Idiom of the Day from the bundled idioms.json.
/// Rotates deterministically every 24 hours per level.
final class IdiomService {
    static let shared = IdiomService()
    private var byLevel: [String: [Idiom]] = [:]
    private var loaded = false
    private init() {}

    private struct Entry: Decodable { let text, definition, example, hebrew: String }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let url = Bundle.main.url(forResource: "idioms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Entry]].self, from: data) else { return }
        for (level, entries) in decoded {
            byLevel[level] = entries.map {
                Idiom(text: $0.text, definition: $0.definition, example: $0.example,
                      hebrew: $0.hebrew, level: level)
            }
        }
    }

    /// The idiom for today: day-of-era index modulo the pool size,
    /// so it changes every 24 hours and never repeats two days in a row.
    func today(level: String) -> Idiom {
        loadIfNeeded()
        let pool = byLevel[level] ?? byLevel["intermediate"] ?? []
        guard !pool.isEmpty else { return .sample }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return pool[day % pool.count]
    }
}

struct BlitzQuestion: Identifiable {
    let id = UUID()
    let word: Word
    let options: [String]
    let correctIndex: Int

    /// The answer shown for a word: its definition, or the Hebrew translation
    /// for words saved without one (flashcards, daily quiz). Empty = unplayable.
    static func answer(for word: Word) -> String {
        let def = word.definition.trimmingCharacters(in: .whitespacesAndNewlines)
        return def.isEmpty ? word.translation.trimmingCharacters(in: .whitespacesAndNewlines) : def
    }

    /// Words that can appear in a Blitz round.
    static func playable(_ words: [Word]) -> [Word] {
        words.filter { !answer(for: $0).isEmpty }
    }

    static func make(from word: Word, allWords: [Word]) -> BlitzQuestion {
        let correct = answer(for: word)
        // Distractors of the same kind (definition vs. Hebrew) so the right
        // answer doesn't stand out, and never a duplicate of the correct one.
        let sameKind = word.definition.isEmpty
            ? allWords.filter { $0.definition.isEmpty }
            : allWords.filter { !$0.definition.isEmpty }
        var others: [String] = []
        for candidate in (sameKind.shuffled() + allWords.shuffled()) where candidate.id != word.id {
            let text = answer(for: candidate)
            if !text.isEmpty, text != correct, !others.contains(text) { others.append(text) }
            if others.count == 3 { break }
        }
        let fillers = word.definition.isEmpty
            ? ["מילה אחרת", "ביטוי רשמי", "מונח ישן"]
            : ["A type of behavior", "An old-fashioned term", "A formal expression"]
        for filler in fillers where others.count < 3 && !others.contains(filler) { others.append(filler) }

        let opts = (others + [correct]).shuffled()
        return BlitzQuestion(word: word, options: opts, correctIndex: opts.firstIndex(of: correct) ?? 0)
    }
}
