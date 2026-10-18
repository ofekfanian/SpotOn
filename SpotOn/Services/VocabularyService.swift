import Foundation

/// Offline English/Hebrew repository by level (vocabulary.json). Lazy + cached.
final class VocabularyService {
    static let shared = VocabularyService()
    private init() {}

    private struct Entry: Decodable { let en: String; let he: String }
    struct Translation { let hebrew: String }

    private var entriesByLevel: [String: [Entry]] = [:]
    private var index: [String: Translation] = [:]
    private var isLoaded = false

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let url = Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Entry]].self, from: data) else { return }
        entriesByLevel = decoded
        for entries in decoded.values {
            for entry in entries { index[entry.en.lowercased()] = Translation(hebrew: entry.he) }
        }
    }

    func translation(for english: String) -> Translation? {
        loadIfNeeded()
        return index[english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    func words(for level: String) -> [Word] {
        loadIfNeeded()
        return (entriesByLevel[level] ?? []).map {
            Word(word: $0.en, translation: $0.he, definition: "", level: level)
        }
    }

    func count(for level: String) -> Int {
        loadIfNeeded()
        return entriesByLevel[level]?.count ?? 0
    }

    /// Word of the Day: deterministic per day and level, offset from the idiom
    /// rotation so the two never move in lockstep.
    func wordOfTheDay(level: String, date: Date = Date()) -> Word? {
        loadIfNeeded()
        let pool = entriesByLevel[level]?.isEmpty == false ? entriesByLevel[level]! : (entriesByLevel["intermediate"] ?? [])
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        // A large prime stride spreads consecutive days across the whole list.
        let entry = pool[(day * 7919 + 13) % pool.count]
        return Word(word: entry.en, translation: entry.he, definition: "", level: level)
    }

    /// Adds words from a downloaded weekly pack to the offline pool, so they
    /// show up in flashcards and in instant translations. Duplicates are skipped.
    func merge(remote words: [(level: String, en: String, he: String)]) {
        loadIfNeeded()
        for w in words where index[w.en.lowercased()] == nil {
            entriesByLevel[w.level, default: []].append(Entry(en: w.en, he: w.he))
            index[w.en.lowercased()] = Translation(hebrew: w.he)
        }
    }
}
