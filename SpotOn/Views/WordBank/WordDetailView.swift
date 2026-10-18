import SwiftUI

struct WordDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme
    let word: Word
    @AppStorage("targetLanguage") private var targetLang = "en"
    @AppStorage("nativeLanguage") private var nativeLang = "he"
    @State private var enrichFailed = false

    /// The live version of the word from the bank — the sheet was opened with
    /// a snapshot, so toggling Mastered/Review must re-read the fresh state.
    private var liveWord: Word {
        wordBankVM.words.first { $0.id == word.id } ?? word
    }

    var body: some View {
        let word = liveWord
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.text(for: targetLang))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(LinearGradient.crystal)
                        let help = word.text(for: nativeLang)
                        if !help.isEmpty {
                            Text(help).font(.title3.bold()).foregroundColor(.crystalMint)
                                .environment(\.layoutDirection, nativeLang == "he" ? .rightToLeft : .leftToRight)
                        }
                        HStack(spacing: 6) {
                            if !word.level.isEmpty {
                                Text(word.level.capitalized).font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.crystalBlue.opacity(0.15)).foregroundColor(.crystalBlue).cornerRadius(8)
                            }
                            if !word.partOfSpeech.isEmpty {
                                Text(word.partOfSpeech.capitalized).font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.crystalMint.opacity(0.15)).foregroundColor(.crystalMint).cornerRadius(8)
                            }
                        }
                    }

                    if !word.definition.isEmpty {
                        InfoSection(title: "Definition", content: word.definition)
                    } else {
                        enrichPrompt(for: word)
                    }
                    if !word.context.isEmpty { InfoSection(title: "Your Context", content: word.context) }

                    let examples = word.examples.filter { !$0.isEmpty }
                    if !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Examples").font(.headline)
                            ForEach(examples, id: \.self) { example in
                                Text("• \(example)").font(.body).foregroundColor(.secondary)
                            }
                        }
                    }

                    if !word.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags").font(.headline)
                            HStack {
                                ForEach(word.tags, id: \.self) { tag in
                                    Text(tag).font(.caption.bold())
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color.crystalBlue.opacity(0.15)).foregroundColor(.crystalBlue).cornerRadius(8)
                                }
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pronunciation").font(.headline)
                        if let phonetic = word.phonetic, !phonetic.isEmpty {
                            HStack(spacing: 8) {
                                Text(word.word.lowercased())
                                    .font(.subheadline.bold()).foregroundColor(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption).foregroundColor(.crystalMint)
                                Text(phonetic)
                                    .font(.subheadline.bold()).foregroundColor(.crystalMint)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.crystalMint.opacity(0.08)).cornerRadius(10)
                        }
                        Button { wordBankVM.speak(word.word) } label: {
                            Label("Hear it", systemImage: "speaker.wave.3.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.crystalMint.opacity(0.15)).foregroundColor(.crystalMint).cornerRadius(14)
                        }
                    }

                    HStack(spacing: 12) {
                        ActionButton(icon: "checkmark.seal.fill", title: word.isMastered ? "Mastered" : "Mark Mastered",
                                     color: .green, isActive: word.isMastered) {
                            guard let uid = authVM.user?.uid else { return }
                            Task { await wordBankVM.toggleMastered(word, uid: uid) }
                        }
                        ActionButton(icon: "arrow.clockwise.circle.fill", title: word.needsReview ? "Reviewing" : "Needs Review",
                                     color: .orange, isActive: word.needsReview) {
                            guard let uid = authVM.user?.uid else { return }
                            Task { await wordBankVM.toggleNeedsReview(word, uid: uid) }
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background {
                ZStack {
                    (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                    ScatteredLettersBackground().ignoresSafeArea()
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension WordDetailView {
    /// Words saved from games skip AI enrichment to spare the daily quota.
    /// This lets the user fill in definition, examples and pronunciation on demand.
    @ViewBuilder
    func enrichPrompt(for word: Word) -> some View {
        let isWorking = word.id.map { wordBankVM.enrichingIDs.contains($0) } ?? false
        VStack(alignment: .leading, spacing: 8) {
            Text("Definition").font(.headline)
            Button {
                guard let uid = authVM.user?.uid else { return }
                enrichFailed = false
                Task { enrichFailed = !(await wordBankVM.enrichAndUpdate(word, uid: uid)) }
            } label: {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().controlSize(.small) }
                    else { Image(systemName: "sparkles") }
                    Text(isWorking ? "Looking it up..." : "Add definition & examples with AI")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity).padding(12)
                .background(Color.crystalBlue.opacity(0.12)).foregroundColor(.crystalBlue).cornerRadius(12)
            }
            .disabled(isWorking)
            if enrichFailed {
                Text("Couldn't reach the AI right now. Try again later.")
                    .font(.caption).foregroundColor(.red)
            }
        }
    }
}

private struct InfoSection: View {
    let title: String; let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(content).font(.body).foregroundColor(.secondary)
        }
    }
}

private struct ActionButton: View {
    let icon: String; let title: String; let color: Color; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption.bold())
                .frame(maxWidth: .infinity).padding()
                .background(isActive ? color.opacity(0.2) : Color(.systemGray5))
                .foregroundColor(isActive ? color : .secondary).cornerRadius(12)
        }
    }
}

#Preview("Light") {
    WordDetailView(word: .sample).environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.light)
}
#Preview("Dark") {
    WordDetailView(word: .sample).environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.dark)
}
