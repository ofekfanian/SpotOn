import Foundation
import FirebaseDatabase

@MainActor
class RealtimeDatabaseService: ObservableObject {
    static let shared = RealtimeDatabaseService()
    private let ref = Database.database(url: "https://spoton-cae4c-default-rtdb.firebaseio.com").reference()

    @Published var streak: Int = 0
    @Published var xp: Int = 0

    private var streakHandle: DatabaseHandle?
    private var xpHandle: DatabaseHandle?

    func startListening(for uid: String) {
        let userRef = ref.child("users").child(uid)
        streakHandle = userRef.child("streak").observe(.value) { [weak self] snap in
            Task { @MainActor in self?.streak = snap.value as? Int ?? 0 }
        }
        xpHandle = userRef.child("xp").observe(.value) { [weak self] snap in
            Task { @MainActor in self?.xp = snap.value as? Int ?? 0 }
        }
    }

    func stopListening(for uid: String) {
        let userRef = ref.child("users").child(uid)
        if let h = streakHandle { userRef.child("streak").removeObserver(withHandle: h) }
        if let h = xpHandle { userRef.child("xp").removeObserver(withHandle: h) }
    }

    func addXP(_ amount: Int, for uid: String) async throws {
        let snap = try await ref.child("users").child(uid).child("xp").getData()
        let current = snap.value as? Int ?? 0
        try await ref.child("users").child(uid).child("xp").setValue(current + amount)
    }

    func checkAndUpdateStreak(for uid: String) async throws {
        let today = DateFormatter.spotDate.string(from: Date())
        let yesterday = DateFormatter.spotDate.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let userRef = ref.child("users").child(uid)

        let lastSnap = try await userRef.child("lastActiveDate").getData()
        let last = lastSnap.value as? String ?? ""
        if last == today { return }

        let currentStreakSnap = try await userRef.child("streak").getData()
        var newStreak = currentStreakSnap.value as? Int ?? 0
        newStreak = (last == yesterday) ? newStreak + 1 : 1

        try await userRef.child("streak").setValue(newStreak)
        try await userRef.child("lastActiveDate").setValue(today)
    }
}
