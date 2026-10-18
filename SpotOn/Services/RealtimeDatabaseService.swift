import Foundation
import FirebaseDatabase

@MainActor
class RealtimeDatabaseService: ObservableObject {
    static let shared = RealtimeDatabaseService()
    private lazy var ref = Database.database(url: "https://spoton-cae4c-default-rtdb.firebaseio.com").reference()

    @Published var streak: Int = 0
    @Published var xp: Int = 0
    /// True once the first XP value arrived from the server.
    @Published private(set) var hasLoaded = false

    /// Fired whenever a counter increases — drives the "sucked-in" gain animation.
    struct GainEvent: Equatable { let amount: Int; let id: UUID }
    @Published var xpGain: GainEvent?
    @Published var streakGain: GainEvent?
    private var lastXPValue: Int?
    private var lastStreakValue: Int?

    /// XP earned per day ("yyyy-MM-dd" -> XP) for the last few weeks.
    /// Feeds the weekly recap, the activity map and the weekly challenge.
    @Published var dailyXP: [String: Int] = [:]
    /// Week keys ("2026-W42") whose challenge bonus was already claimed.
    @Published var claimedChallenges: Set<String> = []

    private var streakHandle: DatabaseHandle?
    private var xpHandle: DatabaseHandle?
    private var dailyHandle: DatabaseHandle?
    private var challengeHandle: DatabaseHandle?

    private var listeningUid: String?

    func startListening(for uid: String) {
        // Remove any previous observers first — auth state changes can call this repeatedly.
        if let previous = listeningUid { stopListening(for: previous) }
        listeningUid = uid
        lastXPValue = nil       // first observed value must not fire a gain animation
        hasLoaded = false
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
                self.hasLoaded = true
            }
        }
        // Only the last 12 weeks are needed for the activity map.
        let since = Calendar.current.date(byAdding: .day, value: -84, to: Date()) ?? Date()
        dailyHandle = userRef.child("daily").queryOrderedByKey()
            .queryStarting(atValue: DateFormatter.spotDate.string(from: since))
            .observe(.value) { [weak self] snap in
                let map = snap.value as? [String: Any] ?? [:]
                let parsed = map.compactMapValues { ($0 as? NSNumber)?.intValue }
                Task { @MainActor in self?.dailyXP = parsed }
            }
        challengeHandle = userRef.child("challenges").observe(.value) { [weak self] snap in
            let keys = Set((snap.value as? [String: Any] ?? [:]).keys)
            Task { @MainActor in self?.claimedChallenges = keys }
        }
    }

    func stopListening(for uid: String) {
        let userRef = ref.child("users").child(uid)
        if let h = streakHandle { userRef.child("streak").removeObserver(withHandle: h); streakHandle = nil }
        if let h = xpHandle { userRef.child("xp").removeObserver(withHandle: h); xpHandle = nil }
        if let h = dailyHandle { userRef.child("daily").removeObserver(withHandle: h); dailyHandle = nil }
        if let h = challengeHandle { userRef.child("challenges").removeObserver(withHandle: h); challengeHandle = nil }
        if listeningUid == uid { listeningUid = nil }
    }

    /// Removes the user's XP, streak, and activity data.
    func deleteUserData(uid: String) async throws {
        try await ref.child("users").child(uid).removeValue()
        streak = 0
        xp = 0
        dailyXP = [:]
        claimedChallenges = []
    }

    func addXP(_ amount: Int, for uid: String) async throws {
        guard amount > 0 else { return }
        // Atomic server-side increments of the total and today's bucket,
        // written together so the history always adds up to the total.
        let day = DateFormatter.spotDate.string(from: Date())
        let inc = ServerValue.increment(NSNumber(value: amount))
        try await ref.child("users").child(uid).updateChildValues(["xp": inc, "daily/\(day)": inc])
    }

    /// Awards the weekly challenge bonus once per week. The claim flag and the
    /// XP are written in one update, so a double tap can't pay out twice.
    func claimChallenge(week: String, bonus: Int, for uid: String) async throws {
        guard !claimedChallenges.contains(week) else { return }
        claimedChallenges.insert(week)
        let day = DateFormatter.spotDate.string(from: Date())
        let inc = ServerValue.increment(NSNumber(value: bonus))
        try await ref.child("users").child(uid).updateChildValues([
            "challenges/\(week)": true, "xp": inc, "daily/\(day)": inc
        ])
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
