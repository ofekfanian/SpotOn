import Foundation
import FirebaseDatabase

@MainActor
class RealtimeDatabaseService: ObservableObject {
    static let shared = RealtimeDatabaseService()
    private lazy var ref = Database.database(url: "https://spoton-cae4c-default-rtdb.firebaseio.com").reference()

    @Published var streak: Int = 0
    @Published var xp: Int = 0

    /// Fired whenever a counter increases — drives the "sucked-in" gain animation.
    struct GainEvent: Equatable { let amount: Int; let id: UUID }
    @Published var xpGain: GainEvent?
    @Published var streakGain: GainEvent?
    private var lastXPValue: Int?
    private var lastStreakValue: Int?

    private var streakHandle: DatabaseHandle?
    private var xpHandle: DatabaseHandle?

    private var listeningUid: String?

    func startListening(for uid: String) {
        // Remove any previous observers first — auth state changes can call this repeatedly.
        if let previous = listeningUid { stopListening(for: previous) }
        listeningUid = uid
        lastXPValue = nil       // first observed value must not fire a gain animation
        lastStreakValue = nil
        let userRef = ref.child("users").child(uid)
        streakHandle = userRef.child("streak").observe(.value) { [weak self] snap in
            Task { @MainActor in
                guard let self else { return }
                let new = snap.value as? Int ?? 0
                if let last = self.lastStreakValue, new > last {
                    self.streakGain = GainEvent(amount: new - last, id: UUID())
                }
                self.lastStreakValue = new
                self.streak = new
            }
        }
        xpHandle = userRef.child("xp").observe(.value) { [weak self] snap in
            Task { @MainActor in
                guard let self else { return }
                let new = snap.value as? Int ?? 0
                if let last = self.lastXPValue, new > last {
                    self.xpGain = GainEvent(amount: new - last, id: UUID())
                }
                self.lastXPValue = new
                self.xp = new
            }
        }
    }

    func stopListening(for uid: String) {
        let userRef = ref.child("users").child(uid)
        if let h = streakHandle { userRef.child("streak").removeObserver(withHandle: h); streakHandle = nil }
        if let h = xpHandle { userRef.child("xp").removeObserver(withHandle: h); xpHandle = nil }
        if listeningUid == uid { listeningUid = nil }
    }

    /// Removes the user's XP, streak, and activity data.
    func deleteUserData(uid: String) async throws {
        try await ref.child("users").child(uid).removeValue()
        streak = 0
        xp = 0
    }

    func addXP(_ amount: Int, for uid: String) async throws {
        // Atomic server-side increment — no read-modify-write race.
        try await ref.child("users").child(uid).child("xp").setValue(ServerValue.increment(NSNumber(value: amount)))
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
