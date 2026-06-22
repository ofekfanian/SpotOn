import Foundation

// MARK: UserProfile
class UserProfile {
    var uid: String
    var email: String
    var username: String
    var level: String
    var inviteCode: String
    var friendUIDs: [String]
    var xp: Int
    var hasOnboarded: Bool
    var nativeLanguage: String
    var targetLanguage: String

    init(uid: String, email: String) {
        self.uid = uid
        self.email = email
        self.username = email.components(separatedBy: "@").first ?? "User"
        self.level = "intermediate"
        self.inviteCode = String(uid.prefix(6).uppercased())
        self.friendUIDs = []
        self.xp = 0
        self.hasOnboarded = false
        self.nativeLanguage = "he"
        self.targetLanguage = "en"
    }

    init(uid: String, data: [String: Any]) {
        self.uid = uid
        self.email = data["email"] as? String ?? ""
        self.username = data["username"] as? String ?? "User"
        self.level = data["level"] as? String ?? "intermediate"
        self.inviteCode = data["inviteCode"] as? String ?? String(uid.prefix(6).uppercased())
        self.friendUIDs = data["friendUIDs"] as? [String] ?? []
        self.xp = data["xp"] as? Int ?? 0
        self.hasOnboarded = data["hasOnboarded"] as? Bool ?? false
        self.nativeLanguage = data["nativeLanguage"] as? String ?? "he"
        self.targetLanguage = data["targetLanguage"] as? String ?? "en"
    }

    var dict: [String: Any] {
        ["email": email, "username": username, "level": level, "inviteCode": inviteCode,
         "friendUIDs": friendUIDs, "xp": xp, "hasOnboarded": hasOnboarded,
         "nativeLanguage": nativeLanguage, "targetLanguage": targetLanguage]
    }
}

// MARK: FriendStats
struct FriendStats {
    let uid: String
    let username: String
    let xp: Int
    let streak: Int
    let wordCount: Int
}
