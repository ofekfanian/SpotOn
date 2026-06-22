import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    // MARK: - Words
    func addWord(_ word: Word, for uid: String) async throws {
        let ref = db.collection("users").document(uid).collection("words")
        try ref.addDocument(from: word)
    }

    func updateWord(_ word: Word, for uid: String) async throws {
        guard let id = word.id else { return }
        try db.collection("users").document(uid).collection("words").document(id).setData(from: word)
    }

    func deleteWord(id: String, for uid: String) async throws {
        try await db.collection("users").document(uid).collection("words").document(id).delete()
    }

    func listenToWords(for uid: String, onChange: @escaping ([Word]) -> Void) -> ListenerRegistration {
        db.collection("users").document(uid).collection("words")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let words = snapshot?.documents.compactMap { try? $0.data(as: Word.self) } ?? []
                onChange(words)
            }
    }

    // MARK: - Idioms
    func fetchTodayIdiom(level: String) async throws -> Idiom {
        let today = DateFormatter.spotDate.string(from: Date())
        let snap = try await db.collection("idioms")
            .whereField("level", isEqualTo: level)
            .whereField("date", isEqualTo: today)
            .limit(to: 1).getDocuments()
        if let doc = snap.documents.first, let idiom = try? doc.data(as: Idiom.self) { return idiom }

        let fallback = try await db.collection("idioms")
            .whereField("level", isEqualTo: level).limit(to: 1).getDocuments()
        if let doc = fallback.documents.first, let idiom = try? doc.data(as: Idiom.self) { return idiom }

        try await seedSampleIdioms()
        return Idiom.sample
    }

    // MARK: - Profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        return try? doc.data(as: UserProfile.self)
    }

    private func seedSampleIdioms() async throws {
        let today = DateFormatter.spotDate.string(from: Date())
        let samples: [Idiom] = [
            Idiom(text: "Hit the nail on the head", definition: "To be exactly right", example: "You hit the nail on the head.", level: "intermediate", date: today),
            Idiom(text: "Bite the bullet", definition: "Endure a painful situation", example: "Just bite the bullet and do it.", level: "beginner", date: today),
            Idiom(text: "Burning the midnight oil", definition: "Working late into the night", example: "She was burning the midnight oil.", level: "advanced", date: today),
        ]
        for idiom in samples { try db.collection("idioms").addDocument(from: idiom) }
    }
}

extension DateFormatter {
    static let spotDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
