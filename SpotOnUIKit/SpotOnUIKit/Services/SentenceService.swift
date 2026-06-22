import Foundation

// MARK: SentenceService
// Offline fill-in-the-blank repository by level. Lazy + cached.
class SentenceService {
    static let shared = SentenceService()
    private init() {}

    struct Item: Decodable {
        let sentence: String
        let answer: String
        let options: [String]
        let he: String
        let fr: String
    }

    private var byLevel: [String: [Item]] = [:]
    private var isLoaded = false

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let url = Bundle.main.url(forResource: "sentences", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Item]].self, from: data) else { return }
        byLevel = decoded
    }

    func sentences(for level: String) -> [Item] {
        loadIfNeeded()
        return byLevel[level] ?? []
    }
}
