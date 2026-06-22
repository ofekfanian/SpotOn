import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @StateObject private var vm = DashboardViewModel()
    @ObservedObject private var rtdb = RealtimeDatabaseService.shared
    @ObservedObject private var profileImage = ProfileImageStore.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var showBlitz = false
    @State private var showFlashcards = false
    @State private var showCardSource = false
    @State private var flashcardDeck: [Word] = []
    @State private var showSnapLearn = false
    @State private var showSentenceSource = false
    @State private var sentenceLevel = "beginner"
    @State private var showSentences = false

    private var level: String { authVM.userProfile?.level ?? "intermediate" }
    private var name: String {
        (authVM.user?.email ?? "").components(separatedBy: "@").first?.capitalized ?? "there"
    }

    // Size classes: Compact width → 2 columns; Regular → 4.
    private var practiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: hSizeClass == .regular ? 4 : 2)
    }
    private var contentMaxWidth: CGFloat { hSizeClass == .regular ? 700 : .infinity }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    statsRow
                    idiomSection
                    practiceSection

                    if wordBankVM.words.count < 2 {
                        Text("Add at least 2 words to unlock Blitz")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    recentWords
                    Spacer(minLength: 32)
                }
                .padding(.top)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showBlitz) {
                BlitzView(words: wordBankVM.words).environmentObject(authVM)
            }
            .fullScreenCover(isPresented: $showFlashcards) {
                FlashcardsView(words: flashcardDeck).environmentObject(authVM)
            }
            .fullScreenCover(isPresented: $showSnapLearn) {
                SnapLearnView().environmentObject(authVM).environmentObject(wordBankVM)
            }
            .fullScreenCover(isPresented: $showSentences) {
                SentenceCompletionView(level: sentenceLevel).environmentObject(authVM)
            }
            .confirmationDialog("Study Flashcards", isPresented: $showCardSource, titleVisibility: .visible) {
                if !wordBankVM.words.isEmpty {
                    Button("My Words (\(wordBankVM.words.count))") { flashcardDeck = wordBankVM.words; showFlashcards = true }
                }
                Button("Beginner Pack") { startPack("beginner") }
                Button("Intermediate Pack") { startPack("intermediate") }
                Button("Advanced Pack") { startPack("advanced") }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Pick a deck to study") }
            .confirmationDialog("Sentence Completion", isPresented: $showSentenceSource, titleVisibility: .visible) {
                Button("Beginner") { startSentences("beginner") }
                Button("Intermediate") { startSentences("intermediate") }
                Button("Advanced") { startSentences("advanced") }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Pick a level") }
            .task { await vm.load(level: level) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Hey, \(name)").font(.title2.bold())
                    Image(systemName: "hand.wave.fill").font(.title3).foregroundColor(.crystalGold)
                }
                Text("Keep building your vocabulary!")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            NavigationLink(destination: SettingsView()) {
                if let img = profileImage.image {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(LinearGradient.crystalShort, lineWidth: 2))
                } else {
                    Image(systemName: "person.circle.fill").font(.title)
                        .foregroundStyle(LinearGradient.crystalShort)
                }
            }
        }
        .padding(.horizontal)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            CrystalStatCard(icon: "flame.fill", color: .orange, label: "Streak", value: "\(rtdb.streak)d")
            CrystalStatCard(icon: "star.fill", color: .crystalGold, label: "XP", value: "\(rtdb.xp)")
            CrystalStatCard(icon: "book.fill", color: .crystalBlue, label: "Words", value: "\(wordBankVM.words.count)")
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var idiomSection: some View {
        if vm.isLoading {
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).frame(height: 160)
                .overlay(ProgressView()).padding(.horizontal)
        } else if let idiom = vm.idiom {
            IdiomCard(idiom: idiom).padding(.horizontal)
        }
    }

    private var practiceSection: some View {
        VStack(spacing: 12) {
            Text("Practice").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            LazyVGrid(columns: practiceColumns, spacing: 12) {
                GameCard(icon: "bolt.fill", title: "60-Sec Blitz", gradient: LinearGradient.crystal,
                         shadow: .crystalBlue, disabled: wordBankVM.words.count < 2) { showBlitz = true }
                GameCard(icon: "rectangle.on.rectangle.angled", title: "Flashcards", gradient: LinearGradient.crystalShort,
                         shadow: .crystalMint, disabled: false) { showCardSource = true }
                GameCard(icon: "text.append", title: "Sentences", gradient: LinearGradient.crystalShort,
                         shadow: .crystalMint, disabled: false) { showSentenceSource = true }
                GameCard(icon: "camera.viewfinder", title: "Snap & Learn", gradient: LinearGradient.crystal,
                         shadow: .crystalGold, disabled: false) { showSnapLearn = true }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var recentWords: some View {
        if !wordBankVM.words.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Words").font(.headline).padding(.horizontal)
                ForEach(wordBankVM.words.prefix(3)) { word in
                    WordRowView(word: word)
                        .padding(.horizontal).padding(.vertical, 10)
                        .background(.ultraThinMaterial).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.crystalBlue.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal)
                }
            }
        }
    }

    private func startPack(_ level: String) {
        flashcardDeck = VocabularyService.shared.words(for: level)
        showFlashcards = true
    }
    private func startSentences(_ level: String) {
        sentenceLevel = level
        showSentences = true
    }
}

// MARK: - Game Card
private struct GameCard: View {
    let icon: String; let title: String; let gradient: LinearGradient; let shadow: Color
    let disabled: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity).frame(height: 88)
            .background(gradient).foregroundColor(.white).cornerRadius(16)
            .shadow(color: shadow.opacity(0.3), radius: 10, y: 4)
        }
        .disabled(disabled).opacity(disabled ? 0.5 : 1)
    }
}

// MARK: - Stat Card
private struct CrystalStatCard: View {
    let icon: String; let color: Color; let label: String; let value: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.title2)
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.ultraThinMaterial).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Idiom Card
private struct IdiomCard: View {
    let idiom: Idiom
    @State private var isExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                    Text("Idiom of the Day").font(.caption.bold())
                }
                .foregroundStyle(LinearGradient.crystalShort)
                Spacer()
                Text(idiom.level.capitalized).font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.crystalBlue.opacity(0.12)).foregroundColor(.crystalBlue).cornerRadius(8)
            }
            Text("\u{201C}\(idiom.text)\u{201D}").font(.title3.bold()).foregroundStyle(LinearGradient.crystal)
            Text(idiom.definition).font(.subheadline).foregroundColor(.secondary)
            if isExpanded {
                Text("Example: \(idiom.example)").font(.caption).foregroundColor(.secondary).italic()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Button { withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() } } label: {
                Text(isExpanded ? "Show less" : "See example").font(.caption.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
            }
        }
        .padding(18).background(.ultraThinMaterial).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1))
        .shadow(color: Color.crystalBlue.opacity(0.08), radius: 12, y: 4)
    }
}
