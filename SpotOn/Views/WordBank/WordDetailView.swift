import SwiftUI
import WebKit

struct WordDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let word: Word
    @AppStorage("targetLanguage") private var targetLang = "en"
    @AppStorage("nativeLanguage") private var nativeLang = "he"
    @State private var showYouGlish = false
    @State private var accent = "en-US"

    private let accents = [("en-US", "American"), ("en-GB", "British"), ("en-AU", "Australian")]

    var body: some View {
        NavigationStack {
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

                    InfoSection(title: "Definition", content: word.definition)
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
                        Picker("Accent", selection: $accent) {
                            ForEach(accents, id: \.0) { code, label in Text(label).tag(code) }
                        }
                        .pickerStyle(.segmented)
                        Button { wordBankVM.speak(word.word, accent: accent) } label: {
                            Label("Hear it", systemImage: "speaker.wave.3.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.crystalMint.opacity(0.15)).foregroundColor(.crystalMint).cornerRadius(14)
                        }
                    }

                    Button { showYouGlish = true } label: {
                        Label("See real usage on YouGlish", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(.ultraThinMaterial).foregroundColor(.primary).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.crystalBlue.opacity(0.25), lineWidth: 1))
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showYouGlish) { YouGlishView(word: word.word) }
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

struct YouGlishView: View {
    let word: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let url = URL(string: "https://youglish.com/pronounce/\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)/english") {
                    WebView(url: url)
                }
            }
            .navigationTitle("YouGlish: \(word)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) { uiView.load(URLRequest(url: url)) }
}

#Preview("Light") {
    WordDetailView(word: .sample).environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.light)
}
#Preview("Dark") {
    WordDetailView(word: .sample).environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.dark)
}
