import FirebaseFirestore

// MARK: FirestoreService
// Per-user word bank + daily idiom (users/{uid}/words, idioms collection).
class FirestoreService {
    static let shared = FirestoreService()
    private init() {}

    private let db = Firestore.firestore()

    private var wordsRef: CollectionReference? {
        guard let uid = AuthService.shared.uid else { return nil }
        return db.collection("users").document(uid).collection("words")
    }

    func listenWords(_ onChange: @escaping ([Word]) -> Void) -> ListenerRegistration? {
        wordsRef?.order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let words = snapshot?.documents.map { doc -> Word in
                    let d = doc.data()
                    let w = Word(word: d["word"] as? String ?? "",
                                 hebrew: d["translation"] as? String ?? "",
                                 french: d["french"] as? String ?? "",
                                 level: d["level"] as? String ?? "")
                    w.id = doc.documentID
                    return w
                } ?? []
                onChange(words)
            }
    }

    func addWord(_ word: Word) {
        wordsRef?.addDocument(data: [
            "word": word.word ?? "",
            "translation": word.hebrew ?? "",
            "french": word.french ?? "",
            "level": word.level ?? "",
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteWord(_ word: Word) {
        guard let id = word.id else { return }
        wordsRef?.document(id).delete()
    }

    // MARK: Idiom of the day
    func fetchTodayIdiom(level: String, completion: @escaping (Idiom) -> Void) {
        db.collection("idioms").whereField("level", isEqualTo: level).limit(to: 1)
            .getDocuments { [weak self] snap, _ in
                if let d = snap?.documents.first?.data() {
                    completion(Idiom(text: d["text"] as? String ?? "",
                                     definition: d["definition"] as? String ?? "",
                                     example: d["example"] as? String ?? ""))
                } else {
                    self?.seedIdioms()
                    completion(.sample)
                }
            }
    }

    private func seedIdioms() {
        let samples: [[String: Any]] = [
            ["text": "Hit the nail on the head", "definition": "To be exactly right", "example": "You hit the nail on the head.", "level": "intermediate"],
            ["text": "Bite the bullet", "definition": "Endure a painful situation", "example": "Just bite the bullet.", "level": "beginner"],
            ["text": "Burning the midnight oil", "definition": "Working late into the night", "example": "She was burning the midnight oil.", "level": "advanced"]
        ]
        for s in samples { db.collection("idioms").addDocument(data: s) }
    }
}
