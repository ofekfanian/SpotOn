import SwiftData
import Foundation

@Model
final class ReadingPassage {
    @Attribute(.unique) var id: String
    var title: String
    var passageDescription: String
    var content: String
    var level: Int          // 1 = Beginner  2 = Intermediate  3 = Advanced
    var orderIndex: Int
    var isCompleted: Bool
    var completedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PassageWord.passage)
    var words: [PassageWord] = []

    init(id: String, title: String, passageDescription: String,
         content: String, level: Int, orderIndex: Int) {
        self.id = id
        self.title = title
        self.passageDescription = passageDescription
        self.content = content
        self.level = level
        self.orderIndex = orderIndex
        self.isCompleted = false
        self.completedAt = nil
    }

    var levelLabel: String {
        switch level {
        case 1: return "Beginner"
        case 2: return "Intermediate"
        case 3: return "Advanced"
        default: return "Unknown"
        }
    }
}

@Model
final class PassageWord {
    var text: String
    var definition: String
    var hebrewTranslation: String
    var isSaved: Bool       // saved to the user's Firestore Word bank
    var isSeen: Bool        // user has opened the definition popup at least once

    @Relationship var passage: ReadingPassage?

    init(text: String, definition: String, hebrewTranslation: String) {
        self.text = text
        self.definition = definition
        self.hebrewTranslation = hebrewTranslation
        self.isSaved = false
        self.isSeen = false
    }

    // Converts to the Firestore Word model so it can be saved to the user's personal bank
    func toWord(passageTitle: String, passageId: String = "") -> Word {
        Word(
            word: text.capitalized,
            translation: hebrewTranslation,
            definition: definition,
            context: "Read in: \(passageTitle)",
            tags: ["Reading", "Passage"],
            level: "intermediate",
            sourcePassageId: passageId.isEmpty ? nil : passageId
        )
    }
}
