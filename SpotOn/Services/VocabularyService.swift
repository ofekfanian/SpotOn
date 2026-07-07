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
}
