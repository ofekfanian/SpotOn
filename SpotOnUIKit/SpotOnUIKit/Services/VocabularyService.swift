import Foundation

// MARK: VocabularyService
// Offline English/Hebrew/French repository, organized by level. Lazy + cached.
class VocabularyService {
    static let shared = VocabularyService()
    private init() {}

    private struct Entry: Decodable { let en: String; let he: String; let fr: String }

    private var byLevel: [String: [Word]] = [:]
    private var isLoaded = false

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let url = Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Entry]].self, from: data) else { return }
        for (level, entries) in decoded {
            byLevel[level] = entries.map { Word(word: $0.en, hebrew: $0.he, french: $0.fr, level: level) }
        }
    }

    func words(for level: String) -> [Word] {
        loadIfNeeded()
        return byLevel[level] ?? []
    }

    func allWords() -> [Word] {
        loadIfNeeded()
        return byLevel.values.flatMap { $0 }
    }
}
