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
    // Spaced repetition (optional, so words saved by older builds still decode)
    var srsStage: Int?          // successful reviews in a row (0 = just missed)
    var nextReview: Date?       // when the word comes back for review
    var masteredAt: Date?       // drives the weekly "mastered" stats

    /// Missed, or its scheduled review time has arrived.
    var isDue: Bool {
        guard !isMastered else { return false }
        if needsReview { return true }
        if let next = nextReview { return next <= Date() }
        return false
    }

    /// Learned recently and waiting for its next review, not due yet.
    var isScheduled: Bool { !isMastered && !isDue && nextReview != nil }

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

    /// Learning stage label shown in the word detail sheet.
    var stageLabel: String {
        if isMastered { return "Mastered" }
        if isDue { return "Due for review" }
        guard let stage = srsStage, stage > 0, let next = nextReview else { return "New" }
        let days = max(1, Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 1)
        return "Step \(stage) of \(SpacedRepetition.masteryStage) · back in \(days)d"
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

// MARK: - Spaced repetition

/// Leitner-style schedule: each correct review pushes the word further out
/// (1, 3, 7, 14 days); four in a row and it's Mastered. A miss resets it.
enum SpacedRepetition {
    static let intervals = [1, 3, 7, 14]          // days until the next review
    static var masteryStage: Int { intervals.count }

    /// Firestore fields to write after a review of a bank word.
    static func fields(after word: Word, knew: Bool, now: Date = Date()) -> [String: Any] {
        guard knew else {
            return ["srsStage": 0, "needsReview": true, "isMastered": false, "nextReview": now]
        }
        let stage = (word.srsStage ?? 0) + 1
        if stage >= masteryStage {
            return ["srsStage": stage, "needsReview": false, "isMastered": true,
                    "masteredAt": now, "nextReview": FieldValue.delete()]
        }
        let next = Calendar.current.date(byAdding: .day, value: intervals[stage - 1], to: now) ?? now
        return ["srsStage": stage, "needsReview": false, "nextReview": next]
    }
}
