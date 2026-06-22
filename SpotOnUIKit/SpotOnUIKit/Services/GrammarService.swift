import Foundation

// MARK: GrammarService
// Offline grammar drills (connectors / tenses). Lazy + cached.
class GrammarService {
    static let shared = GrammarService()
    private init() {}

    struct Item: Decodable {
        let sentence: String
        let answer: String
        let options: [String]
        let explanation: String
        let he: String
    }

    private var byTopic: [String: [Item]] = [:]
    private var isLoaded = false

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let url = Bundle.main.url(forResource: "grammar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Item]].self, from: data) else { return }
        byTopic = decoded
    }

    func items(for topic: String) -> [Item] {
        loadIfNeeded()
        return byTopic[topic] ?? []
    }
}
