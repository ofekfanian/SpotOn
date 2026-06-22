import Foundation
import FirebaseFirestore
import FirebaseDatabase

class FriendsService {
    static let shared = FriendsService()
    private lazy var db = Firestore.firestore()
    private lazy var rtdb = Database.database(url: "https://spoton-cae4c-default-rtdb.firebaseio.com").reference()

    func addFriend(inviteCode: String, for uid: String) async throws {
        let snap = try await db.collection("users")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
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

    func fetchLeaderboard(friendUIDs: [String], myUID: String) async throws -> [FriendStats] {
        let allUIDs = [myUID] + friendUIDs
        var stats: [FriendStats] = []
        for uid in allUIDs {
            let profileDoc = try await db.collection("users").document(uid).getDocument()
            guard let profile = try? profileDoc.data(as: UserProfile.self) else { continue }
            let rtSnap = try await rtdb.child("users").child(uid).getData()
            let rt = rtSnap.value as? [String: Any]
            let xp = rt?["xp"] as? Int ?? profile.xp
            let streak = rt?["streak"] as? Int ?? 0
            let wordsSnap = try await db.collection("users").document(uid)
                .collection("words").count.getAggregation(source: .server)
            let wordCount = Int(truncating: wordsSnap.count)
            stats.append(FriendStats(uid: uid,
                                     username: profile.username ?? profile.email.components(separatedBy: "@").first ?? "User",
                                     xp: xp, streak: streak, wordCount: wordCount))
        }
        return stats.sorted { $0.xp > $1.xp }
    }
}
