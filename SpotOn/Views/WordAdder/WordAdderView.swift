import SwiftUI

struct WordAdderView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme

    @State private var word = ""
    @State private var translation = ""
    @State private var isSaving = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("The Word") {
                    TextField("e.g. Serendipity", text: $word)
                        .font(.headline)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: word) { _, newValue in
                            if let t = VocabularyService.shared.translation(for: newValue) {
                                translation = t.hebrew
                            }
                        }
                    HStack(spacing: 6) {
                        Image(systemName: "character.bubble").foregroundColor(.crystalMint).font(.caption)
                        TextField("Hebrew translation (optional)", text: $translation)
                            .environment(\.layoutDirection, .rightToLeft)
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
                    .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
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
    }

    private func save() async {
        guard let uid = authVM.user?.uid else { return }
        isSaving = true
        let newWord = Word(word: word.trimmingCharacters(in: .whitespaces).capitalized,
                           translation: translation,
                           definition: "",
                           level: authVM.userProfile?.level ?? "intermediate")
        await wordBankVM.addWord(newWord, uid: uid)   // AI enrichment fills the rest
        try? await RealtimeDatabaseService.shared.addXP(10, for: uid)
        isSaving = false
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccess = false
            word = ""; translation = ""
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
