import Foundation

/// A themed set of new words published weekly, outside the app binary.
struct ContentPack: Codable, Identifiable {
    struct PackWord: Codable { let en: String; let he: String; let level: String }

    let id: String
    let title: String
    let description: String
    let icon: String
    let publishedAt: String      // "yyyy-MM-dd"; packs dated in the future stay hidden
    let words: [PackWord]

    /// The pack's words as flashcard-ready Word values.
    var asWords: [Word] {
        words.map { Word(word: $0.en, translation: $0.he, definition: "", tags: ["Weekly Pack"], level: $0.level) }
    }
}

/// Downloads weekly vocabulary packs from the repo's `content/weekly.json`.
///
/// New content ships by committing to that file, with no App Store update
/// and no Firebase rules to change. The last good copy is cached on disk, so packs
/// keep working offline, and the feed is re-checked at most every 6 hours.
@MainActor
final class ContentPackService: ObservableObject {
    static let shared = ContentPackService()

    @Published private(set) var packs: [ContentPack] = []

    private let feedURL = URL(string: "https://raw.githubusercontent.com/ofekfanian/SpotOn/main/content/weekly.json")!
    private let lastFetchKey = "contentPacksLastFetch"
    private let refreshInterval: TimeInterval = 6 * 3600

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("content_packs.json")
    }

    private struct Feed: Codable { let packs: [ContentPack] }

    private init() {
        if let data = try? Data(contentsOf: cacheURL), let feed = try? JSONDecoder().decode(Feed.self, from: data) {
            apply(feed.packs)
        }
    }

    /// The newest pack that is already published.
    var latest: ContentPack? {
        let today = DateFormatter.spotDate.string(from: Date())
        return packs.filter { $0.publishedAt <= today }.max { $0.publishedAt < $1.publishedAt }
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard !AppEnv.isPreview else { return }
        let last = UserDefaults.standard.double(forKey: lastFetchKey)
        guard force || Date().timeIntervalSince1970 - last > refreshInterval else { return }
        var request = URLRequest(url: feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let feed = try? JSONDecoder().decode(Feed.self, from: data) else { return }
        try? data.write(to: cacheURL, options: .atomic)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
        apply(feed.packs)
    }

    private func apply(_ newPacks: [ContentPack]) {
        packs = newPacks
        let today = DateFormatter.spotDate.string(from: Date())
        let live = newPacks.filter { $0.publishedAt <= today }.flatMap(\.words)
        VocabularyService.shared.merge(remote: live.map { ($0.level, $0.en, $0.he) })
    }
}
