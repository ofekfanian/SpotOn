import Foundation
import FirebaseFirestore

struct Word: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var word: String
    var translation: String   // Hebrew
    var french: String        // French
    var definition: String
    var context: String
    var tags: [String]
    var level: String
    var isMastered: Bool
    var needsReview: Bool
    var createdAt: Date

    init(
        word: String,
        translation: String = "",
        french: String = "",
        definition: String,
        context: String = "",
        tags: [String] = [],
        level: String = "intermediate"
    ) {
        self.word = word
        self.translation = translation
        self.french = french
        self.definition = definition
        self.context = context
        self.tags = tags
        self.level = level
        self.isMastered = false
        self.needsReview = false
        self.createdAt = Date()
    }

    // Text in a given language code (en/he/fr).
    func text(for code: String) -> String {
        switch code {
        case "he": return translation
        case "fr": return french
        default:   return word
        }
    }

    static let sample = Word(
        word: "Serendipity",
        translation: "מקריות מאושרת",
        french: "sérendipité",
        definition: "Finding something good by accident",
        context: "Heard in Friends Season 2",
        tags: ["Casual"],
        level: "intermediate"
    )
}
