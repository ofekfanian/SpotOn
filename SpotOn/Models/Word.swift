import Foundation
import FirebaseFirestore

struct Word: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var word: String
    var translation: String   // Hebrew
    var definition: String
    var context: String
    var tags: [String]
    var level: String
    var isMastered: Bool
    var needsReview: Bool
    var createdAt: Date
    // Enrichment fields, populated by LLMEnrichmentService after the word is saved
    var partOfSpeech: String
    var examples: [String]      // [business, casual, tech] sentences from Gemini
    var phonetic: String?       // simple respelling, e.g. "noh" for know
    var sourcePassageId: String? // ID of the ReadingPassage that introduced this word

    init(
        word: String,
        translation: String = "",
        definition: String,
        context: String = "",
        tags: [String] = [],
        level: String = "intermediate",
        partOfSpeech: String = "",
        examples: [String] = [],
        sourcePassageId: String? = nil
    ) {
        self.word = word
        self.translation = translation
        self.definition = definition
        self.context = context
        self.tags = tags
        self.level = level
        self.isMastered = false
        self.needsReview = false
        self.createdAt = Date()
        self.partOfSpeech = partOfSpeech
        self.examples = examples
        self.sourcePassageId = sourcePassageId
    }

    func text(for code: String) -> String {
        code == "he" ? translation : word
    }

    static let sample = Word(
        word: "Serendipity",
        translation: "מקריות מאושרת",
        definition: "Finding something good by accident",
        context: "Heard in Friends Season 2",
        tags: ["Casual"],
        level: "intermediate",
        partOfSpeech: "noun",
        examples: [
            "The serendipity of the merger created unexpected revenue streams.",
            "Meeting my best friend was pure serendipity.",
            "A serendipitous bug fix revealed a deeper optimisation in the cache layer."
        ]
    )
}
