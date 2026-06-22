import FirebaseDatabase

// MARK: RealtimeDatabaseService
// XP + daily streak in the Realtime Database (users/{uid}/xp, streak, lastActiveDate).
class RealtimeDatabaseService {
    static let shared = RealtimeDatabaseService()
    private init() {}

    // Explicit URL — the plist has no DATABASE_URL, so build the default one.
    static let dbURL = "https://spoton-cae4c-default-rtdb.firebaseio.com"
    private let ref = Database.database(url: RealtimeDatabaseService.dbURL).reference()
    private(set) var xp = 0
    private(set) var streak = 0
    var onUpdate: (() -> Void)?

    private var uid: String?
    private var xpHandle: DatabaseHandle?
    private var streakHandle: DatabaseHandle?

    func start(uid: String) {
        self.uid = uid
        checkStreak(uid: uid)
        let userRef = ref.child("users").child(uid)
        xpHandle = userRef.child("xp").observe(.value) { [weak self] snap in
            self?.xp = snap.value as? Int ?? 0
            self?.onUpdate?()
        }
        streakHandle = userRef.child("streak").observe(.value) { [weak self] snap in
            self?.streak = snap.value as? Int ?? 0
            self?.onUpdate?()
        }
    }

    func stop() {
        guard let uid else { return }
        let userRef = ref.child("users").child(uid)
        if let h = xpHandle { userRef.child("xp").removeObserver(withHandle: h) }
        if let h = streakHandle { userRef.child("streak").removeObserver(withHandle: h) }
        xp = 0; streak = 0; self.uid = nil
    }

    func addXP(_ amount: Int) {
        guard let uid else { return }
        let xpRef = ref.child("users").child(uid).child("xp")
        xpRef.getData { _, snap in
            let current = (snap?.value as? Int) ?? 0
            xpRef.setValue(current + amount)
        }
    }

    private func checkStreak(uid: String) {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let yesterday = fmt.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let userRef = ref.child("users").child(uid)
        userRef.child("lastActiveDate").getData { _, snap in
            let last = (snap?.value as? String) ?? ""
            if last == today { return }
            userRef.child("streak").getData { _, sSnap in
                var newStreak = (sSnap?.value as? Int) ?? 0
                newStreak = (last == yesterday) ? newStreak + 1 : 1
                userRef.child("streak").setValue(newStreak)
                userRef.child("lastActiveDate").setValue(today)
            }
        }
    }
}
