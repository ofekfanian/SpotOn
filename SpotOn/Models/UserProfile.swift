import Foundation

struct UserProfile: Codable {
    var uid: String
    var email: String
    var displayName: String
    var level: String
    var hasCompletedOnboarding: Bool
    var username: String?
    var inviteCode: String
    var friendUIDs: [String]
    var xp: Int
    var nativeLanguage: String?
    var targetLanguage: String?

    init(uid: String, email: String, displayName: String = "") {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.level = "intermediate"
        self.hasCompletedOnboarding = false
        self.username = email.components(separatedBy: "@").first
        self.inviteCode = String(uid.prefix(6).uppercased())
        self.friendUIDs = []
        self.xp = 0
        self.nativeLanguage = "he"
        self.targetLanguage = "en"
    }
}

struct FriendStats: Identifiable, Codable {
    var id: String { uid }
    var uid: String
    var username: String
    var xp: Int
    var streak: Int
    var wordCount: Int
}
