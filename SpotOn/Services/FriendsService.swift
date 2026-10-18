import Foundation
import FirebaseFirestore
import FirebaseDatabase

class FriendsService {
    static let shared = FriendsService()
    private lazy var db = Firestore.firestore()
    private lazy var rtdb = Database.database(url: "https://spoton-cae4c-default-rtdb.firebaseio.com").reference()

    func addFriend(inviteCode: String, for uid: String) async throws {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let snap = try await db.collection("users")
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1).getDocuments()
        guard let doc = snap.documents.first else {
            throw NSError(domain: "FriendsService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        let friendUID = doc.documentID
        guard friendUID != uid else {
            throw NSError(domain: "FriendsService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Can't add yourself"])
        }
        try await db.collection("users").document(uid)
            .updateData(["friendUIDs": FieldValue.arrayUnion([friendUID])])
        try await db.collection("users").document(friendUID)
            .updateData(["friendUIDs": FieldValue.arrayUnion([uid])])
    }

    /// Loads every member in parallel. A friend whose data can't be read
    /// (deleted account, rules, flaky network) is skipped instead of
    /// failing the whole leaderboard.
    func fetchLeaderboard(friendUIDs: [String], myUID: String) async throws -> [FriendStats] {
        let allUIDs = Array(Set([myUID] + friendUIDs))
        let stats = await withTaskGroup(of: FriendStats?.self) { group in
            for uid in allUIDs {
                group.addTask { try? await self.fetchStats(uid: uid) }
            }
            var result: [FriendStats] = []
            for await s in group { if let s { result.append(s) } }
            return result
        }
        return stats.sorted { $0.xp > $1.xp }
    }

    private func fetchStats(uid: String) async throws -> FriendStats? {
        let profileDoc = try await db.collection("users").document(uid).getDocument()
        guard let profile = try? profileDoc.data(as: UserProfile.self) else { return nil }
        let rt = (try? await rtdb.child("users").child(uid).getData())?.value as? [String: Any]
        let xp = rt?["xp"] as? Int ?? profile.xp
        let streak = rt?["streak"] as? Int ?? 0
        let wordsSnap = try? await db.collection("users").document(uid)
            .collection("words").count.getAggregation(source: .server)
        let wordCount = wordsSnap.map { Int(truncating: $0.count) } ?? 0
        let name = profile.username ?? profile.email.components(separatedBy: "@").first ?? "User"
        return FriendStats(uid: uid, username: name, xp: xp, streak: streak, wordCount: wordCount)
    }
}
