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

    private enum CodingKeys: String, CodingKey {
        case uid, email, displayName, level, hasCompletedOnboarding, username
        case inviteCode, friendUIDs, xp, nativeLanguage, targetLanguage
    }

    /// Tolerant decoding: a profile written by an older build (missing a field)
    /// still loads instead of failing and sending the user back to onboarding.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = try c.decode(String.self, forKey: .uid)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        level = try c.decodeIfPresent(String.self, forKey: .level) ?? "intermediate"
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        username = try c.decodeIfPresent(String.self, forKey: .username)
        inviteCode = try c.decodeIfPresent(String.self, forKey: .inviteCode) ?? String(uid.prefix(6).uppercased())
        friendUIDs = try c.decodeIfPresent([String].self, forKey: .friendUIDs) ?? []
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        nativeLanguage = try c.decodeIfPresent(String.self, forKey: .nativeLanguage)
        targetLanguage = try c.decodeIfPresent(String.self, forKey: .targetLanguage)
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
