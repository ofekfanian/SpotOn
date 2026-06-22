import Foundation
import FirebaseFirestore
import AVFoundation

@MainActor
class WordBankViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var searchText = ""
    @Published var selectedTag: String? = nil

    private var listener: ListenerRegistration?
    private let synth = AVSpeechSynthesizer()

    var filtered: [Word] {
        words.filter { word in
            let matchesSearch = searchText.isEmpty || word.word.localizedCaseInsensitiveContains(searchText)
            let matchesTag = selectedTag == nil || word.tags.contains(selectedTag!)
            return matchesSearch && matchesTag
        }
    }

    func startListening(uid: String) {
        guard !AppEnv.isPreview else { return }
        listener = FirestoreService.shared.listenToWords(for: uid) { [weak self] words in
            Task { @MainActor in self?.words = words }
        }
    }

    func stopListening() { listener?.remove() }

    func addWord(_ word: Word, uid: String) async {
        try? await FirestoreService.shared.addWord(word, for: uid)
    }

    func deleteWord(_ word: Word, uid: String) async {
        guard let id = word.id else { return }
        try? await FirestoreService.shared.deleteWord(id: id, for: uid)
    }

    func toggleMastered(_ word: Word, uid: String) async {
        var updated = word; updated.isMastered.toggle()
        try? await FirestoreService.shared.updateWord(updated, for: uid)
    }

    func toggleNeedsReview(_ word: Word, uid: String) async {
        var updated = word; updated.needsReview.toggle()
        try? await FirestoreService.shared.updateWord(updated, for: uid)
    }

    func speak(_ text: String, accent: String = "en-US") {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        utterance.rate = 0.45
        synth.speak(utterance)
    }
}
