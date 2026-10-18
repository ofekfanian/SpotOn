import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private lazy var db = Firestore.firestore()

    private func wordsRef(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("words")
    }

    // MARK: - Words
    /// Adds the word and returns the new Firestore document ID.
    @discardableResult
    func addWord(_ word: Word, for uid: String) async throws -> String {
        try wordsRef(uid).addDocument(from: word).documentID
    }

    func updateWord(_ word: Word, for uid: String) async throws {
        guard let id = word.id else { return }
        try wordsRef(uid).document(id).setData(from: word)
    }

    /// Writes only the given fields. Used for status toggles and AI enrichment
    /// so two concurrent writers never overwrite each other's changes
    /// (e.g. enrichment finishing after the user already marked a word Mastered).
    func updateWordFields(id: String, for uid: String, fields: [String: Any]) async throws {
        try await wordsRef(uid).document(id).updateData(fields)
    }

    func deleteWord(id: String, for uid: String) async throws {
        try await wordsRef(uid).document(id).delete()
    }

    func listenToWords(for uid: String, onChange: @escaping ([Word]) -> Void) -> ListenerRegistration {
        wordsRef(uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                // A nil snapshot is a transient error; keep the last good list.
                guard let snapshot else { return }
                onChange(snapshot.documents.compactMap { try? $0.data(as: Word.self) })
            }
    }

    // MARK: - Profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
    }

    /// Returns nil only when the profile document truly doesn't exist.
    /// Network failures throw, so callers never mistake "offline" for "new user".
    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: UserProfile.self)
    }

    /// Deletes the user's words subcollection and profile document.
    func deleteAllUserData(uid: String) async throws {
        let userDoc = db.collection("users").document(uid)
        let words = try await userDoc.collection("words").getDocuments()
        // A Firestore batch is capped at 500 writes.
        for chunk in stride(from: 0, to: words.documents.count, by: 450) {
            let batch = db.batch()
            words.documents[chunk..<min(chunk + 450, words.documents.count)]
                .forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        try await userDoc.delete()
    }

}

extension DateFormatter {
    /// Day key used for streaks and once-a-day gates. Pinned to the Gregorian
    /// calendar so a device set to e.g. the Hebrew calendar gets the same keys.
    static let spotDate: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
