import FirebaseFirestore
import FirebaseDatabase

// MARK: FriendsService
// Friend invites + leaderboard, mirroring the original SwiftUI logic.
class FriendsService {
    static let shared = FriendsService()
    private init() {}

    private let db = Firestore.firestore()
    private let rtdb = Database.database(url: RealtimeDatabaseService.dbURL).reference()

    func addFriend(inviteCode: String, uid: String, completion: @escaping (String?) -> Void) {
        db.collection("users").whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1).getDocuments { snap, _ in
                guard let doc = snap?.documents.first else { completion("User not found"); return }
                let friendUID = doc.documentID
                guard friendUID != uid else { completion("You can't add yourself"); return }
                self.db.collection("users").document(uid)
                    .updateData(["friendUIDs": FieldValue.arrayUnion([friendUID])])
                self.db.collection("users").document(friendUID)
                    .updateData(["friendUIDs": FieldValue.arrayUnion([uid])])
                completion(nil)
            }
    }

    func fetchLeaderboard(friendUIDs: [String], myUID: String,
                          completion: @escaping ([FriendStats]) -> Void) {
        let allUIDs = [myUID] + friendUIDs
        var stats: [FriendStats] = []
        let group = DispatchGroup()

        for uid in allUIDs {
            group.enter()
            db.collection("users").document(uid).getDocument { snap, _ in
                let data = snap?.data() ?? [:]
                let username = data["username"] as? String ?? "User"
                let profileXP = data["xp"] as? Int ?? 0
                self.rtdb.child("users").child(uid).getData { _, rt in
                    let rtData = rt?.value as? [String: Any]
                    let xp = rtData?["xp"] as? Int ?? profileXP
                    let streak = rtData?["streak"] as? Int ?? 0
                    self.db.collection("users").document(uid).collection("words").getDocuments { wSnap, _ in
                        let count = wSnap?.documents.count ?? 0
                        stats.append(FriendStats(uid: uid, username: username, xp: xp, streak: streak, wordCount: count))
                        group.leave()
                    }
                }
            }
        }
        group.notify(queue: .main) {
            completion(stats.sorted { $0.xp > $1.xp })
        }
    }
}
