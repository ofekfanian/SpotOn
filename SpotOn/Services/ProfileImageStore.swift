import SwiftUI

@MainActor
final class ProfileImageStore: ObservableObject {
    static let shared = ProfileImageStore()
    @Published var image: UIImage?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("profile.jpg")
    }()

    private init() {
        if let data = try? Data(contentsOf: fileURL) { image = UIImage(data: data) }
    }

    func save(_ uiImage: UIImage) {
        image = uiImage
        if let data = uiImage.jpegData(compressionQuality: 0.8) { try? data.write(to: fileURL) }
    }

    func remove() {
        image = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
