import Foundation
import FirebaseFirestore
import AVFoundation

@MainActor
class WordBankViewModel: ObservableObject {

    // MARK: - Published state

    @Published var words: [Word] = []
    @Published var searchText = ""
    @Published var statusFilter: StatusFilter = .all
    @Published var isEnriching = false

    /// Words are categorized automatically by their learning status.
    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case learning = "Learning"
        case review = "To Review"
        case mastered = "Mastered"

        func matches(_ w: Word) -> Bool {
            switch self {
            case .all:      return true
            case .mastered: return w.isMastered
            case .review:   return w.needsReview && !w.isMastered
            case .learning: return !w.isMastered && !w.needsReview
            }
        }
    }

    // Pagination
    private let pageSize = 50
    @Published private var visibleCount = 50

    // MARK: - Private

    private var listener: ListenerRegistration?
    private let synth = AVSpeechSynthesizer()

    // MARK: - Derived collections

    /// All words matching the current search / status filter.
    var filtered: [Word] {
        words.filter { w in
            let matchesSearch = searchText.isEmpty
                || w.word.localizedCaseInsensitiveContains(searchText)
                || w.definition.localizedCaseInsensitiveContains(searchText)
            return matchesSearch && statusFilter.matches(w)
        }
    }

    /// Marks a word as known: clears the review flag and sets Mastered.
    func markKnown(_ word: Word, uid: String) async {
        var updated = word
        updated.needsReview = false
        updated.isMastered = true
        try? await FirestoreService.shared.updateWord(updated, for: uid)
    }

    /// Visible page of results, grows by `pageSize` each time `loadNextPage()` is called.
    var paginated: [Word] { Array(filtered.prefix(visibleCount)) }

    var hasMore: Bool { filtered.count > visibleCount }

    // MARK: - Pagination

    func loadNextPage() {
        guard hasMore else { return }
        visibleCount += pageSize
    }

    private func resetPagination() { visibleCount = pageSize }

    // MARK: - Firebase listener

    func startListening(uid: String) {
        guard !AppEnv.isPreview else { return }
        listener?.remove()   // avoid stacking duplicate listeners on repeated onAppear
        listener = FirestoreService.shared.listenToWords(for: uid) { [weak self] words in
            Task { @MainActor in
                self?.words = words
                self?.resetPagination()
            }
        }
    }

    func stopListening() { listener?.remove(); listener = nil }

    // MARK: - CRUD

    /// Adds the word, then (optionally) enriches it with Gemini metadata in the
    /// background. Bulk additions like mastered flashcards skip enrichment to
    /// preserve the daily AI quota.
    func addWord(_ word: Word, uid: String, enrich: Bool = true) async {
        guard let id = try? await FirestoreService.shared.addWord(word, for: uid) else { return }
        guard enrich else { return }
        var saved = word
        saved.id = id
        Task { await self.enrichAndUpdate(saved, uid: uid) }
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

    // MARK: - LLM Enrichment

    /// Fetches definition, part-of-speech, 3 usage examples and a related idiom
    /// from Gemini, then persists the enriched word to Firestore.
    func enrichAndUpdate(_ word: Word, uid: String) async {
        isEnriching = true
        defer { isEnriching = false }
        do {
            let e = try await LLMEnrichmentService.shared.enrich(word: word.word)
            var updated = word
            if updated.definition.isEmpty { updated.definition = e.definition }
            if updated.translation.isEmpty { updated.translation = e.hebrew }
            updated.partOfSpeech = e.partOfSpeech
            updated.phonetic = e.phonetic
            updated.examples = [e.exampleBusiness, e.exampleCasual, e.exampleTech]
            if updated.level == "intermediate" || updated.level.isEmpty {
                updated.level = e.level
            }
            try? await FirestoreService.shared.updateWord(updated, for: uid)
        } catch {
            print("[WordBank] Enrichment failed for '\(word.word)': \(error.localizedDescription)")
        }
    }

    // MARK: - Audio

    func speak(_ text: String, accent: String = "en-US") {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        utterance.rate = 0.45
        synth.speak(utterance)
    }
}
