import SwiftUI

struct WordAdderView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme

    @State private var word = ""
    @State private var translation = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    /// The translation we filled in from the offline dictionary — replaced
    /// as the word changes, but a translation the user typed is never touched.
    @State private var autoTranslation = ""
    @FocusState private var focused: Bool

    private var trimmedWord: String { word.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool { !trimmedWord.isEmpty && wordBankVM.contains(trimmedWord) }

    var body: some View {
        Form {
            Section("The Word") {
                TextField("e.g. Serendipity", text: $word)
                    .font(.headline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: word) { _, newValue in
                        guard translation.isEmpty || translation == autoTranslation else { return }
                        let suggestion = VocabularyService.shared.translation(for: newValue)?.hebrew ?? ""
                        translation = suggestion
                        autoTranslation = suggestion
                    }
                HStack(spacing: 6) {
                    Image(systemName: "character.bubble").foregroundColor(.crystalMint).font(.caption)
                    TextField("Hebrew translation (optional)", text: $translation)
                        .environment(\.layoutDirection, .rightToLeft)
                        .focused($focused)
                }
                if isDuplicate {
                    Label("Already in your Word Bank", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold()).foregroundColor(.orange)
                }
            }

            Section {
                Button { Task { await save() } } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() }
                        else { Label("Save Word", systemImage: "checkmark.circle.fill").font(.headline) }
                        Spacer()
                    }
                }
                .disabled(trimmedWord.isEmpty || isDuplicate || isSaving)
            } footer: {
                Text("AI fills in the definition, translation, examples and level for you.")
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()
            }
        }
        .navigationTitle("Add Word")
        .overlay { if showSuccess { SuccessOverlay().transition(.scale.combined(with: .opacity)) } }
        .applyTabBarVisibility()
    }

    private func save() async {
        guard let uid = authVM.user?.uid, !isDuplicate else { return }
        focused = false
        isSaving = true
        // Capitalize only the first letter, so phrases keep their natural case
        // ("Break the ice", not "Break The Ice").
        let text = trimmedWord.prefix(1).uppercased() + trimmedWord.dropFirst()
        let newWord = Word(word: text,
                           translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
                           definition: "",
                           level: authVM.userProfile?.level ?? "intermediate")
        let added = await wordBankVM.addWord(newWord, uid: uid)   // AI enrichment fills the rest
        if added { try? await RealtimeDatabaseService.shared.addXP(10, for: uid) }
        isSaving = false
        guard added else { return }
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSuccess = false }
            word = ""; translation = ""; autoTranslation = ""
        }
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

#Preview("Light") { MainTabView(initialTab: 2).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 2).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
