import Foundation

// MARK: ImageBankService
// Curated image repository organized by category (images.json). Each entry is
// a stable LoremFlickr "lock" id, so the same id always returns the same
// Creative-Commons photo for that category. Lazy + cached.
class ImageBankService {
    static let shared = ImageBankService()
    private init() {}

    private var byCategory: [String: [Int]] = [:]
    private var isLoaded = false

    var categories: [String] {
        loadIfNeeded()
        return byCategory.keys.sorted()
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let url = Bundle.main.url(forResource: "images", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) else { return }
        byCategory = decoded
    }

    func imageURLs(for category: String) -> [String] {
        loadIfNeeded()
        return (byCategory[category] ?? []).map {
            "https://loremflickr.com/700/500/\(category)?lock=\($0)"
        }
    }

    func randomImageURL(for category: String) -> URL? {
        guard let str = imageURLs(for: category).randomElement() else { return nil }
        return URL(string: str)
    }
}
