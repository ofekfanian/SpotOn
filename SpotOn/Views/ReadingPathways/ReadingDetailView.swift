import SwiftUI
import SwiftData
import UIKit

// MARK: - Reading Detail View

struct ReadingDetailView: View {
    let passage: ReadingPassage

    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @EnvironmentObject var readingVM: ReadingPathwayViewModel
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme)  private var scheme
    @Environment(\.dismiss)      private var dismiss

    private enum Phase { case reading, quiz, done }

    @State private var phase: Phase = .reading
    @State private var quizItems: [QuizItem] = []

    // Pop-up state
    @State private var tappedWord: PassageWord? = nil
    @State private var wordScreenRect: CGRect    = .zero

    // Text selection bar
    @State private var selectedText: String? = nil

    // Toast
    @State private var showSavedToast = false

    // XP awarded for the just-finished quiz (0 on re-reads)
    @State private var earnedXP = 0

    // Text of a word whose AI lookup failed (the popup stops spinning)
    @State private var failedLookup: String? = nil

    var body: some View {
        ZStack {
            background
            switch phase {
            case .reading:
                readingContent
            case .quiz:
                QuizView(
                    items: quizItems,
                    passage: passage,
                    onFinish: { correctCount in
                        // Award XP like the other modes (×5 per correct answer),
                        // but only the first time this passage is completed.
                        if !passage.isCompleted, correctCount > 0, let uid = authVM.user?.uid {
                            earnedXP = correctCount * 5
                            Task { try? await RealtimeDatabaseService.shared.addXP(correctCount * 5, for: uid) }
                        } else {
                            earnedXP = 0
                        }
                        readingVM.markCompleted(passage, context: ctx)
                        withAnimation { phase = .done }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            case .done:
                completionView
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // Glassmorphism word pop-up (floats over everything)
            if let word = tappedWord {
                popupOverlay(word: word)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(passage.title).font(.headline).lineLimit(1)
                    Text(passage.levelLabel)
                        .font(.caption2.bold()).foregroundColor(levelColor)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ttsControls
            }
        }
        .onAppear {
            readingVM.autoMarkKnownWords(passage: passage, bankWords: wordBankVM.words, context: ctx)
        }
        .onDisappear { readingVM.stopSpeaking() }
        .overlay(alignment: .top) {
            if showSavedToast {
                savedToast
                    .padding(.top, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Selection bar appears when user long-presses any text
        .safeAreaInset(edge: .bottom) {
            if let text = selectedText, !text.isEmpty {
                selectionSaveBar(text: text)
            }
        }
        .animation(.spring(response: 0.35), value: showSavedToast)
        .animation(.easeInOut(duration: 0.28), value: tappedWord?.text)
        .animation(.spring(response: 0.4), value: phase == .reading)
    }

    // MARK: Reading content

    private var readingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                passageHeader
                PassageTextView(
                    content: passage.content,
                    targetWords: passage.words.sorted { $0.text < $1.text },
                    onWordTapped: { word, rect in
                        readingVM.markWordSeen(word, context: ctx)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            tappedWord    = (tappedWord?.text == word.text) ? nil : word
                            wordScreenRect = rect
                        }
                    },
                    onAnyWordTapped: { text, rect in
                        showBubble(for: text, at: rect)
                    },
                    onSelectionChanged: { text in
                        selectedText = text
                    }
                )

                newWordsPill
                startQuizButton
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.clear)
        .onTapGesture {
            if tappedWord != nil {
                withAnimation { tappedWord = nil }
            }
        }
    }

    /// Shows the glass popup for ANY tapped word (not only highlighted targets).
    /// Translation comes from the local vocabulary first; Gemini fills the gaps.
    private func showBubble(for text: String, at rect: CGRect) {
        if tappedWord?.text.lowercased() == text.lowercased() {
            withAnimation { tappedWord = nil }
            return
        }
        let local = VocabularyService.shared.translation(for: text)
        let transient = PassageWord(
            text: text,
            definition: "",
            hebrewTranslation: local?.hebrew ?? ""
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            tappedWord = transient
            wordScreenRect = rect
        }
        failedLookup = nil
        // Fill definition (and translation if still missing) in the background
        Task {
            guard let e = try? await LLMEnrichmentService.shared.enrich(word: text) else {
                if tappedWord === transient { failedLookup = text }
                return
            }
            guard tappedWord === transient else { return }   // popup already changed
            transient.definition = e.definition
            if transient.hebrewTranslation.isEmpty { transient.hebrewTranslation = e.hebrew }
        }
    }

    // MARK: Passage header

    private var passageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(passage.levelLabel, systemImage: levelIcon)
                    .font(.caption.bold())
                    .foregroundColor(levelColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(levelColor.opacity(0.12))
                    .cornerRadius(8)

                Label("\(passage.words.count) vocabulary words", systemImage: "textformat")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text(passage.passageDescription)
                .font(.subheadline).foregroundColor(.secondary)
        }
    }

    // MARK: New words pill

    private var newWordsPill: some View {
        let unseen = passage.words.filter { !$0.isSeen }
        return Group {
            if !unseen.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").font(.caption).foregroundColor(.crystalGold)
                    Text("\(unseen.count) new word\(unseen.count == 1 ? "" : "s") to discover")
                        .font(.caption.bold()).foregroundColor(.crystalGold)
                    Text("(highlighted in red)")
                        .font(.caption2).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(Color.crystalGold.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.crystalGold.opacity(0.25), lineWidth: 1))
            }
        }
    }

    // MARK: Quiz button

    private var startQuizButton: some View {
        Button {
            readingVM.stopSpeaking()
            quizItems = readingVM.generateQuiz(for: passage)
            if quizItems.isEmpty {
                // Too few target words to build questions: finish the passage
                // directly instead of opening an empty quiz screen.
                readingVM.markCompleted(passage, context: ctx)
                earnedXP = 0
                withAnimation { phase = .done }
            } else {
                withAnimation(.spring(response: 0.4)) { phase = .quiz }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "pencil.and.outline")
                Text("Test Your Understanding")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient.crystalShort)
            .cornerRadius(17)
            .shadow(color: .crystalBlue.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: TTS controls (toolbar)

    private var ttsControls: some View {
        HStack(spacing: 8) {
            if readingVM.isSpeaking {
                Button(action: readingVM.pauseOrResume) {
                    Image(systemName: readingVM.isPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline)
                        .foregroundStyle(LinearGradient.crystalShort)
                }
                Button(action: readingVM.stopSpeaking) {
                    Image(systemName: "stop.fill")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            } else {
                Button { readingVM.speak(passage.content) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(LinearGradient.crystalShort)
                }
            }
        }
    }

    // MARK: Pop-up overlay

    private func popupOverlay(word: PassageWord) -> some View {
        let isSaved = word.isSaved || wordBankVM.words.contains { $0.word.lowercased() == word.text.lowercased() }

        return GeometryReader { geo in
            let geoOrigin = geo.frame(in: .global)
            let cardW: CGFloat = 280
            let cardH: CGFloat = 165
            let screenW = UIScreen.main.bounds.width
            let rawX = wordScreenRect.midX - geoOrigin.minX
            let rawY = wordScreenRect.minY - geoOrigin.minY
            let clampedX = min(max(rawX, cardW / 2 + 10), screenW - cardW / 2 - 10)
            let finalY: CGFloat = rawY > cardH + 60
                ? rawY - cardH / 2 - 10      // above the word
                : rawY + wordScreenRect.height + cardH / 2 + 10  // below

            WordPopupCard(
                word: word,
                isSaved: isSaved,
                lookupFailed: failedLookup == word.text,
                onSave: {
                    guard let uid = authVM.user?.uid else { return }
                    let fw = word.toWord(passageTitle: passage.title, passageId: passage.id)
                    Task {
                        await wordBankVM.addWord(fw, uid: uid)
                        readingVM.markWordSaved(word, context: ctx)
                        withAnimation { showSavedToast = true }
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation { showSavedToast = false }
                    }
                },
                onDismiss: { withAnimation { tappedWord = nil } }
            )
            .frame(width: cardW)
            .position(x: clampedX, y: finalY)
        }
        .ignoresSafeArea()
    }

    // MARK: Selection save bar

    private func selectionSaveBar(text: String) -> some View {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 12) {
            Text("'\(clean)'")
                .font(.subheadline.bold())
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button {
                guard let uid = authVM.user?.uid, !clean.isEmpty else { return }
                guard !wordBankVM.contains(clean) else {
                    selectedText = nil
                    withAnimation { showSavedToast = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation { showSavedToast = false }
                    }
                    return
                }
                let word = Word(
                    word: clean.capitalized,
                    definition: "",
                    context: "Selected from: \(passage.title)",
                    tags: ["Reading", "Manual"],
                    level: passage.levelLabel.lowercased()
                )
                Task {
                    await wordBankVM.addWord(word, uid: uid)
                    selectedText = nil
                    withAnimation { showSavedToast = true }
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    withAnimation { showSavedToast = false }
                }
            } label: {
                Label("Save to Word Bank", systemImage: "plus.circle.fill")
                    .font(.caption.bold()).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient.crystalShort).cornerRadius(10)
            }
            .buttonStyle(.plain)

            Button { selectedText = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.crystalBlue.opacity(0.2)), alignment: .top)
    }

    // MARK: Completion view

    private var completionView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient.crystal)
            CrystalText(text: "Passage Complete!", font: .title.bold())
            if earnedXP > 0 {
                Text("+\(earnedXP) XP").font(.title3.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
            }
            Text("You've finished '\(passage.title)'. New words have been marked as seen.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            VStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Continue Reading")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(LinearGradient.crystalShort).cornerRadius(17)
                }
                Button { withAnimation { phase = .reading } } label: {
                    Label("Read Again", systemImage: "arrow.counterclockwise")
                        .font(.subheadline).foregroundColor(.crystalBlue)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: Toast

    private var savedToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.crystalMint)
            Text("Saved to Word Bank!").font(.subheadline.bold())
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
        .background(.ultraThinMaterial).cornerRadius(26)
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .overlay(Capsule().strokeBorder(LinearGradient.crystal.opacity(0.3), lineWidth: 1))
    }

    // MARK: Helpers

    private var background: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [levelColor.opacity(0.04), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var levelColor: Color {
        switch passage.level {
        case 1: return .crystalMint
        case 2: return .crystalBlue
        case 3: return .crystalGold
        default: return .crystalBlue
        }
    }

    private var levelIcon: String {
        switch passage.level {
        case 1: return "leaf.fill"
        case 2: return "flame.fill"
        case 3: return "bolt.fill"
        default: return "star.fill"
        }
    }
}

// MARK: - Word Popup Card

private struct WordPopupCard: View {
    let word: PassageWord
    let isSaved: Bool
    var lookupFailed = false
    let onSave: () -> Void
    let onDismiss: () -> Void

    var translation: String { word.hebrewTranslation }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(word.text)
                    .font(.title3.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3).foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            if word.definition.isEmpty && lookupFailed {
                Text("Definition unavailable right now.")
                    .font(.subheadline).italic().foregroundColor(.secondary)
            } else if word.definition.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking it up...")
                        .font(.subheadline).italic().foregroundColor(.secondary)
                }
            } else {
                Text(word.definition)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !translation.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "textformat.alt")
                        .font(.caption).foregroundColor(.crystalBlue)
                    Text(translation)
                        .font(.caption.bold()).foregroundColor(.crystalBlue)
                }
            }

            Button(action: onSave) {
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(isSaved ? "Saved!" : "Save to Word Bank")
                }
                .font(.caption.bold()).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(isSaved ? AnyView(Color.crystalMint) : AnyView(LinearGradient.crystalShort))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isSaved)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(LinearGradient.crystal.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
    }
}

// MARK: - UITextView wrapper (interactive passage text)

struct PassageTextView: UIViewRepresentable {
    let content: String
    let targetWords: [PassageWord]
    var onWordTapped: (PassageWord, CGRect) -> Void
    var onAnyWordTapped: (String, CGRect) -> Void = { _, _ in }
    var onSelectionChanged: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable   = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tv.textContainer.lineFragmentPadding = 0

        // Override link appearance: red, no underline
        tv.linkTextAttributes = [
            .foregroundColor: UIColor.systemRed,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        tv.delegate = context.coordinator
        context.coordinator.textView = tv

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributedText = buildAttributedString(colorScheme: uiView.traitCollection.userInterfaceStyle)
        uiView.attributedText = attributedText
        context.coordinator.parent = self
        uiView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    private func buildAttributedString(colorScheme: UIUserInterfaceStyle) -> NSAttributedString {
        let textColor = colorScheme == .dark ? UIColor.label : UIColor.label
        let baseFont  = UIFont.systemFont(ofSize: 17, weight: .regular)

        let result = NSMutableAttributedString(
            string: content,
            attributes: [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: {
                    let ps = NSMutableParagraphStyle()
                    ps.lineSpacing    = 6
                    ps.paragraphSpacing = 0
                    return ps
                }()
            ]
        )

        for (index, word) in targetWords.enumerated() {
            guard !word.text.isEmpty else { continue }
            guard let url = URL(string: "word://\(index)") else { continue }
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word.text))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsContent = content as NSString
            let range = NSRange(location: 0, length: nsContent.length)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                result.addAttributes([
                    .link: url,
                    .foregroundColor: UIColor.systemRed,
                    .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
                ], range: match.range)
            }
        }
        return result
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: PassageTextView
        weak var textView: UITextView?

        init(parent: PassageTextView) { self.parent = parent }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let tv = textView else { return }
            let location = recognizer.location(in: tv)
            let layoutManager = tv.layoutManager
            let charIndex = layoutManager.characterIndex(
                for: location,
                in: tv.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            guard charIndex < tv.textStorage.length else { return }

            var effectiveRange = NSRange()
            if let url = tv.textStorage.attribute(.link, at: charIndex, effectiveRange: &effectiveRange) as? URL,
               url.scheme == "word",
               let indexStr = url.host,
               let wordIndex = Int(indexStr),
               wordIndex < parent.targetWords.count {

                let screenRect = rect(for: effectiveRange, in: tv)
                DispatchQueue.main.async {
                    self.parent.onWordTapped(self.parent.targetWords[wordIndex], screenRect)
                }
            } else {
                // Not a highlighted target word — detect the plain word under the tap
                let text = tv.textStorage.string as NSString
                let wordRange = wordBoundary(at: charIndex, in: text)
                guard wordRange.length > 1 else { return }
                let word = text.substring(with: wordRange)
                    .trimmingCharacters(in: CharacterSet.letters.inverted)
                guard word.count > 1, word.rangeOfCharacter(from: .letters) != nil else { return }

                let screenRect = rect(for: wordRange, in: tv)
                DispatchQueue.main.async {
                    self.parent.onAnyWordTapped(word, screenRect)
                }
            }
        }

        private func wordBoundary(at index: Int, in text: NSString) -> NSRange {
            let letters = CharacterSet.letters
            func isLetter(_ i: Int) -> Bool {
                guard i >= 0, i < text.length else { return false }
                let ch = text.character(at: i)
                guard let scalar = Unicode.Scalar(ch) else { return false }
                return letters.contains(scalar)
            }
            guard isLetter(index) else { return NSRange(location: index, length: 0) }
            var start = index, end = index
            while isLetter(start - 1) { start -= 1 }
            while isLetter(end + 1) { end += 1 }
            return NSRange(location: start, length: end - start + 1)
        }

        private func rect(for range: NSRange, in tv: UITextView) -> CGRect {
            let glyphRange = tv.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = tv.layoutManager.boundingRect(forGlyphRange: glyphRange, in: tv.textContainer)
            rect = rect.offsetBy(dx: tv.textContainerInset.left, dy: tv.textContainerInset.top)
            return tv.convert(rect, to: nil)
        }

        // Don't cancel swipe/scroll gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            if range.length > 0, let text = (textView.text as NSString?)?.substring(with: range) {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let words  = clean.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                let result = words.count <= 4 ? clean : nil   // only short selections (1-4 words)
                DispatchQueue.main.async { self.parent.onSelectionChanged(result) }
            } else {
                DispatchQueue.main.async { self.parent.onSelectionChanged(nil) }
            }
        }

        // Suppress default tap behavior for word:// links on iOS 17+
        @available(iOS 17, *)
        func textView(_ textView: UITextView,
                      primaryActionFor textItem: UITextItem,
                      defaultAction: UIAction) -> UIAction? {
            if case .link(let url) = textItem.content, url.scheme == "word" { return nil }
            return defaultAction
        }
    }
}

// MARK: - Quiz View

private struct QuizView: View {
    let items: [QuizItem]
    let passage: ReadingPassage
    let onFinish: (Int) -> Void   // passes the number of correct answers

    @State private var current = 0
    @State private var selected: Int? = nil
    @State private var fillAnswer = ""
    @State private var showResult = false
    @State private var correctCount = 0
    @FocusState private var fillFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if showResult {
                    resultView
                } else if let item = items[safe: current] {
                    quizHeader
                    quizCard(item: item)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.28), value: current)
        .animation(.spring(response: 0.35), value: showResult)
    }

    private var quizHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(current + 1) of \(items.count)")
                    .font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
                Text("\(correctCount) correct")
                    .font(.caption.bold()).foregroundColor(.crystalMint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient.crystalShort)
                        .frame(width: geo.size.width * (Double(current) / Double(max(items.count, 1))), height: 5)
                        .animation(.spring(response: 0.4), value: current)
                }
            }
            .frame(height: 5)
        }
    }

    @ViewBuilder
    private func quizCard(item: QuizItem) -> some View {
        switch item.type {
        case let .multipleChoice(question, options, correctIndex):
            VStack(spacing: 16) {
                questionBadge(label: "Multiple Choice", icon: "list.bullet")
                Text(question).font(.headline).multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                        let st = answerState(i: i, correct: correctIndex)
                        Button { guard selected == nil else { return }; submitMC(i, correct: correctIndex) } label: {
                            HStack {
                                Text(opt)
                                    .font(.subheadline.bold())
                                    .environment(\.layoutDirection, .rightToLeft)
                                Spacer()
                                if selected != nil {
                                    Image(systemName: st == .correct ? "checkmark.circle.fill" : (st == .wrong ? "xmark.circle.fill" : "circle"))
                                        .foregroundColor(st == .correct ? .crystalMint : (st == .wrong ? .red : .secondary.opacity(0.4)))
                                }
                            }
                            .padding(14)
                            .background(st == .correct ? Color.crystalMint.opacity(0.1) : (st == .wrong ? Color.red.opacity(0.08) : Color(.systemBackground).opacity(0.01)))
                            .background(.ultraThinMaterial)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(st == .correct ? Color.crystalMint.opacity(0.5) : (st == .wrong ? Color.red.opacity(0.35) : Color.crystalBlue.opacity(0.15)), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(selected != nil)
                    }
                }
                if selected != nil { nextButton }
            }
            .padding(18).background(.ultraThinMaterial).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal.opacity(0.25), lineWidth: 1))

        case let .fillBlank(before, after, answer):
            VStack(spacing: 16) {
                questionBadge(label: "Fill in the Blank", icon: "pencil.line")
                VStack(spacing: 4) {
                    Text((before + " _____ " + after).trimmingCharacters(in: .whitespaces))
                        .font(.body).italic().multilineTextAlignment(.center)
                        .foregroundColor(.primary.opacity(0.85))
                    Text("Hint: \(items[current].hebrewHint)")
                        .font(.caption).foregroundColor(.secondary)
                }
                TextField("Type the missing word...", text: $fillAnswer)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.systemBackground).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(fillFocused ? Color.crystalBlue.opacity(0.55) : Color.crystalBlue.opacity(0.2), lineWidth: 1.5))
                    .focused($fillFocused)
                    .disabled(selected != nil)
                if selected != nil {
                    let isCorrect = fillAnswer.trimmingCharacters(in: .whitespaces).lowercased() == answer.lowercased()
                    HStack(spacing: 6) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(isCorrect ? "Correct!" : "Answer: \(answer)")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(isCorrect ? .crystalMint : .red)
                    nextButton
                } else {
                    Button { fillFocused = false; submitFill(answer: answer) } label: {
                        Text("Check Answer")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(fillAnswer.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? AnyView(Color.secondary.opacity(0.3)) : AnyView(LinearGradient.crystalShort))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(fillAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18).background(.ultraThinMaterial).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal.opacity(0.25), lineWidth: 1))
        }
    }

    private var nextButton: some View {
        Button {
            if current < items.count - 1 {
                selected = nil; fillAnswer = ""; current += 1
            } else {
                showResult = true
            }
        } label: {
            Text(current < items.count - 1 ? "Next Question" : "See Results")
                .font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(LinearGradient.crystalShort).cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var resultView: some View {
        VStack(spacing: 24) {
            Image(systemName: score >= 0.7 ? "star.fill" : "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient.crystalShort)
            CrystalText(text: "\(correctCount)/\(items.count) Correct", font: .title.bold())
            Text(scoreMessage).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button { onFinish(correctCount) } label: {
                Text("Complete Passage").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient.crystalShort).cornerRadius(17)
            }
            .buttonStyle(.plain)
        }
        .padding(24).background(.ultraThinMaterial).cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(LinearGradient.crystal.opacity(0.3), lineWidth: 1))
    }

    private func questionBadge(label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption.bold())
            Text(label).font(.caption.bold())
        }
        .foregroundColor(.crystalBlue)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Color.crystalBlue.opacity(0.1)).cornerRadius(8)
    }

    // MARK: Helpers

    private enum AnswerState { case neutral, correct, wrong }

    private func answerState(i: Int, correct: Int) -> AnswerState {
        guard let sel = selected else { return .neutral }
        if i == correct { return .correct }
        if i == sel     { return .wrong   }
        return .neutral
    }

    private func submitMC(_ choice: Int, correct: Int) {
        selected = choice
        if choice == correct { correctCount += 1; SoundService.playCorrect() } else { SoundService.playWrong() }
    }

    private func submitFill(answer: String) {
        selected = 0
        let isCorrect = fillAnswer.trimmingCharacters(in: .whitespaces).lowercased() == answer.lowercased()
        if isCorrect { correctCount += 1; SoundService.playCorrect() } else { SoundService.playWrong() }
    }

    private var score: Double { Double(correctCount) / Double(max(items.count, 1)) }

    private var scoreMessage: String {
        switch score {
        case 0.9...: return "Outstanding! You have a strong command of this vocabulary."
        case 0.7...: return "Great work! A few words to review and you will master this passage."
        case 0.5...: return "Good effort. Try rereading the passage and focus on the highlighted words."
        default:     return "Keep going. Re-read the passage once more before retaking the quiz."
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    NavigationStack {
        ReadingDetailView(passage: {
            let p = ReadingPassage(id: "preview", title: "Preview Passage",
                                   passageDescription: "A sample passage for preview.",
                                   content: "Every morning, David stops at his favorite coffee shop before heading to the office. The barista greets him with a warm smile.",
                                   level: 1, orderIndex: 0)
            let w = PassageWord(text: "barista", definition: "A person trained to make espresso drinks.",
                                hebrewTranslation: "בריסטה")
            w.passage = p
            p.words.append(w)
            return p
        }())
        .environmentObject(AuthViewModel())
        .environmentObject(WordBankViewModel())
        .environmentObject(ReadingPathwayViewModel())
    }
    .preferredColorScheme(.light)
}
