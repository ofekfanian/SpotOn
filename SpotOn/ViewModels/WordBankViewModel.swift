import Foundation
import FirebaseFirestore

@MainActor
class WordBankViewModel: ObservableObject {

    // MARK: - Published state

    @Published var words: [Word] = []
    @Published var searchText = "" { didSet { resetPagination() } }
    @Published var statusFilter: StatusFilter = .all { didSet { resetPagination() } }
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
    /// IDs of words currently being enriched (drives per-word spinners).
    @Published private(set) var enrichingIDs: Set<String> = []

    // MARK: - Derived collections

    /// All words matching the current search / status filter.
    var filtered: [Word] {
        words.filter { w in
            let matchesSearch = searchText.isEmpty
                || w.word.localizedCaseInsensitiveContains(searchText)
                || w.definition.localizedCaseInsensitiveContains(searchText)
                || w.translation.localizedCaseInsensitiveContains(searchText)
            return matchesSearch && statusFilter.matches(w)
        }
    }

    /// True when the bank already holds this word (case-insensitive).
    func contains(_ text: String) -> Bool {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return words.contains { $0.word.lowercased() == key }
    }

    /// Marks a word as known: clears the review flag and sets Mastered.
    func markKnown(_ word: Word, uid: String) async {
        guard let id = word.id else { return }
        try? await FirestoreService.shared.updateWordFields(
            id: id, for: uid, fields: ["needsReview": false, "isMastered": true])
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
            Task { @MainActor in self?.words = words }
        }
    }

    func stopListening() { listener?.remove(); listener = nil }

    // MARK: - CRUD

    /// Adds the word, then (optionally) enriches it with Gemini metadata in the
    /// background. Bulk additions like mastered flashcards skip enrichment to
    /// preserve the daily AI quota.
    /// Returns false when nothing was added (already in the bank, or the write failed).
    @discardableResult
    func addWord(_ word: Word, uid: String, enrich: Bool = true) async -> Bool {
        guard !word.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !contains(word.word) else { return false }
        guard let id = try? await FirestoreService.shared.addWord(word, for: uid) else { return false }
        if enrich {
            var saved = word
            saved.id = id
            Task { await self.enrichAndUpdate(saved, uid: uid) }
        }
        return true
    }

    func deleteWord(_ word: Word, uid: String) async {
        guard let id = word.id else { return }
        try? await FirestoreService.shared.deleteWord(id: id, for: uid)
    }

    func toggleMastered(_ word: Word, uid: String) async {
        guard let id = word.id else { return }
        // Mastering a word also settles it: it no longer needs review.
        var fields: [String: Any] = ["isMastered": !word.isMastered]
        if !word.isMastered { fields["needsReview"] = false }
        try? await FirestoreService.shared.updateWordFields(id: id, for: uid, fields: fields)
    }

    func toggleNeedsReview(_ word: Word, uid: String) async {
        guard let id = word.id else { return }
        // Flagging for review means it isn't mastered anymore.
        var fields: [String: Any] = ["needsReview": !word.needsReview]
        if !word.needsReview { fields["isMastered"] = false }
        try? await FirestoreService.shared.updateWordFields(id: id, for: uid, fields: fields)
    }

    // MARK: - LLM Enrichment

    /// Fetches definition, part-of-speech, 3 usage examples and a related idiom
    /// from Gemini, then writes only the enrichment fields — status flags the
    /// user changed in the meantime are never overwritten.
    /// Returns false when the lookup failed (quota, network, bad response).
    @discardableResult
    func enrichAndUpdate(_ word: Word, uid: String) async -> Bool {
        guard let id = word.id, !enrichingIDs.contains(id) else { return false }
        enrichingIDs.insert(id)
        isEnriching = true
        defer {
            enrichingIDs.remove(id)
            isEnriching = !enrichingIDs.isEmpty
        }
        do {
            let e = try await LLMEnrichmentService.shared.enrich(word: word.word)
            var fields: [String: Any] = [
                "partOfSpeech": e.partOfSpeech,
                "phonetic": e.phonetic,
                "examples": [e.exampleBusiness, e.exampleCasual, e.exampleTech].filter { !$0.isEmpty }
            ]
            if word.definition.isEmpty { fields["definition"] = e.definition }
            if word.translation.isEmpty, !e.hebrew.isEmpty { fields["translation"] = e.hebrew }
            // Gemini returns a CEFR band (A1–C2); the app buckets levels as
            // beginner/intermediate/advanced. Map it so the word still matches
            // the level filters in flashcards and elsewhere.
            if word.level == "intermediate" || word.level.isEmpty {
                fields["level"] = Self.coarseLevel(fromCEFR: e.level)
            }
            try await FirestoreService.shared.updateWordFields(id: id, for: uid, fields: fields)
            return true
        } catch {
            print("[WordBank] Enrichment failed for '\(word.word)': \(error.localizedDescription)")
            return false
        }
    }

    /// Collapses a CEFR band (A1–C2) into the app's coarse level buckets.
    /// Unknown input falls back to "intermediate".
    private static func coarseLevel(fromCEFR cefr: String) -> String {
        switch cefr.uppercased().prefix(1) {
        case "A": return "beginner"
        case "C": return "advanced"
        case "B": return "intermediate"
        default:  return "intermediate"
        }
    }

    // MARK: - Audio

    func speak(_ text: String, accent: String = "en-US") {
        // Shared, pre-warmed synthesizer: no first-use lag, and a new word
        // interrupts the previous one instead of queueing behind it.
        SpeechService.shared.speak(text, accent: accent)
    }
}
