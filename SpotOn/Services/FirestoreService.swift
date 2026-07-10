import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private lazy var db = Firestore.firestore()

    // MARK: - Words
    /// Adds the word and returns the new Firestore document ID.
    @discardableResult
    func addWord(_ word: Word, for uid: String) async throws -> String {
        let ref = db.collection("users").document(uid).collection("words")
        return try ref.addDocument(from: word).documentID
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

    // MARK: - Profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        return try? doc.data(as: UserProfile.self)
    }

    /// Deletes the user's words subcollection and profile document.
    func deleteAllUserData(uid: String) async throws {
        let userDoc = db.collection("users").document(uid)
        let words = try await userDoc.collection("words").getDocuments()
        if !words.documents.isEmpty {
            let batch = db.batch()
            words.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        try await userDoc.delete()
    }

}

extension DateFormatter {
    static let spotDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
