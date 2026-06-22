import Foundation
import FirebaseFirestore

struct Idiom: Identifiable, Codable {
    @DocumentID var id: String?
    var text: String
    var definition: String
    var example: String
    var level: String
    var date: String

    init(text: String, definition: String, example: String, level: String, date: String) {
        self.text = text
        self.definition = definition
        self.example = example
        self.level = level
        self.date = date
    }

    static let sample = Idiom(
        text: "Hit the nail on the head",
        definition: "To be exactly right about something",
        example: "You really hit the nail on the head with that suggestion.",
        level: "intermediate",
        date: "2024-01-01"
    )
}

struct BlitzQuestion: Identifiable {
    let id = UUID()
    let word: Word
    let options: [String]
    let correctIndex: Int

    static func make(from word: Word, allWords: [Word]) -> BlitzQuestion {
        var others = allWords.filter { $0.id != word.id }.shuffled().prefix(3).map(\.definition)
        while others.count < 3 {
            others.append(["A type of behavior", "An old-fashioned term", "A formal expression"][others.count])
        }
        var opts = Array(others) + [word.definition]
        opts.shuffle()
        let correct = opts.firstIndex(of: word.definition) ?? 0
        return BlitzQuestion(word: word, options: opts, correctIndex: correct)
    }
}
