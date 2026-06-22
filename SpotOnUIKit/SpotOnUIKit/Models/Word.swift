import Foundation

// MARK: Word
class Word {
    var id: String?          // Firestore document id
    var word: String?
    var hebrew: String?
    var french: String?
    var level: String?

    init() {}

    init(word: String, hebrew: String, french: String, level: String) {
        self.word = word
        self.hebrew = hebrew
        self.french = french
        self.level = level
    }

    // Text in a specific language code.
    func text(for code: String) -> String {
        switch code {
        case "he": return hebrew ?? ""
        case "fr": return french ?? ""
        default:   return word ?? ""
        }
    }

    // What the user is learning vs. their own language (set in onboarding).
    var learnText: String { text(for: AppSettings.targetLanguage) }
    var helpText: String { text(for: AppSettings.nativeLanguage) }

    // Mock data in the lecturer's style.
    func mockData() -> [Word] {
        var words: [Word] = []
        words.append(Word(word: "Serendipity", hebrew: "מקריות מאושרת", french: "sérendipité", level: "Advanced"))
        words.append(Word(word: "House", hebrew: "בית", french: "maison", level: "Beginner"))
        words.append(Word(word: "Improve", hebrew: "לשפר", french: "améliorer", level: "Intermediate"))
        words.append(Word(word: "Water", hebrew: "מים", french: "eau", level: "Beginner"))
        words.append(Word(word: "Resilience", hebrew: "חוסן", french: "résilience", level: "Advanced"))
        words.append(Word(word: "Friend", hebrew: "חבר", french: "ami", level: "Beginner"))
        words.append(Word(word: "Opportunity", hebrew: "הזדמנות", french: "opportunité", level: "Intermediate"))
        words.append(Word(word: "Eloquent", hebrew: "רהוט", french: "éloquent", level: "Advanced"))
        words.append(Word(word: "Quality", hebrew: "איכות", french: "qualité", level: "Intermediate"))
        words.append(Word(word: "Coffee", hebrew: "קפה", french: "café", level: "Beginner"))
        return words
    }
}
