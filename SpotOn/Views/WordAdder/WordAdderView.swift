import SwiftUI

struct WordAdderView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel

    @State private var word = ""
    @State private var translation = ""
    @State private var french = ""
    @State private var definition = ""
    @State private var context = ""
    @State private var selectedTags: Set<String> = []
    @State private var level = "intermediate"
    @State private var isSaving = false
    @State private var showSuccess = false

    private let tags = ["Tech", "Casual", "Business", "Academic", "Slang"]
    private let levels = ["beginner", "intermediate", "advanced"]

    var body: some View {
        NavigationStack {
            Form {
                Section("The Word") {
                    TextField("e.g. Serendipity", text: $word)
                        .font(.headline)
                        .onChange(of: word) { _, newValue in
                            if let t = VocabularyService.shared.translation(for: newValue) {
                                translation = t.hebrew; french = t.french
                            }
                        }
                    HStack(spacing: 6) {
                        Image(systemName: "character.bubble").foregroundColor(.crystalMint).font(.caption)
                        TextField("Hebrew translation", text: $translation).environment(\.layoutDirection, .rightToLeft)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "character.bubble").foregroundColor(.crystalBlue).font(.caption)
                        TextField("French translation", text: $french)
                    }
                    TextField("Definition (English)", text: $definition, axis: .vertical).lineLimit(2...4)
                }

                Section("Tags") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(tag: tag, isSelected: selectedTags.contains(tag)) {
                                if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    Picker("Level", selection: $level) {
                        ForEach(levels, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Where did you hear it? (optional)", text: $context, axis: .vertical).lineLimit(1...3)
                } header: { Text("Context") } footer: { Text("Adding context helps you remember it later.") }

                Section {
                    Button { Task { await save() } } label: {
                        HStack {
                            Spacer()
                            if isSaving { ProgressView() }
                            else { Label("Save Word", systemImage: "checkmark.circle.fill").font(.headline) }
                            Spacer()
                        }
                    }
                    .disabled(word.isEmpty || definition.isEmpty || isSaving)
                }
            }
            .navigationTitle("Add Word")
            .overlay { if showSuccess { SuccessOverlay().transition(.scale.combined(with: .opacity)) } }
        }
    }

    private func save() async {
        guard let uid = authVM.user?.uid else { return }
        isSaving = true
        let newWord = Word(word: word, translation: translation, french: french,
                           definition: definition, context: context, tags: Array(selectedTags), level: level)
        await wordBankVM.addWord(newWord, uid: uid)
        try? await RealtimeDatabaseService.shared.addXP(10, for: uid)
        isSaving = false
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccess = false
            word = ""; translation = ""; french = ""; definition = ""; context = ""; selectedTags = []
        }
    }
}

private struct TagChip: View {
    let tag: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(tag).font(.caption.bold())
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.crystalBlue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary).cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

private struct SuccessOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(.crystalMint)
            Text("Word Added!").font(.title2.bold())
        }
        .padding(40).background(.ultraThinMaterial).cornerRadius(24)
    }
}
