import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @StateObject private var vm = DashboardViewModel()
    @ObservedObject private var rtdb = RealtimeDatabaseService.shared
    @ObservedObject private var profileImage = ProfileImageStore.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var scheme

    @State private var showBlitz = false
    @State private var showFlashcards = false
    @State private var showSnapLearn = false
    @State private var showSentences = false
    @State private var levelUpTo: String? = nil

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
            .background {
                ZStack {
                    (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                    ScatteredLettersBackground().ignoresSafeArea()
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showBlitz, onDismiss: checkPromotion) {
                BlitzView(words: wordBankVM.words).environmentObject(authVM)
            }
            .fullScreenCover(isPresented: $showFlashcards, onDismiss: checkPromotion) {
                FlashcardsView(level: level)
                    .environmentObject(authVM)
                    .environmentObject(wordBankVM)
            }
            .fullScreenCover(isPresented: $showSnapLearn, onDismiss: checkPromotion) {
                SnapLearnView().environmentObject(authVM).environmentObject(wordBankVM)
            }
            .fullScreenCover(isPresented: $showSentences, onDismiss: checkPromotion) {
                SentenceCompletionView(level: level).environmentObject(authVM)
            }
            .task { await vm.load(level: level) }
            .onChange(of: rtdb.xp) { _, _ in
                // While a game cover is up the banner would be invisible —
                // the cover's onDismiss re-checks instead.
                guard !showBlitz, !showFlashcards, !showSentences, !showSnapLearn else { return }
                checkPromotion()
            }
            .overlay(alignment: .top) {
                if let promoted = levelUpTo {
                    LevelUpBanner(level: promoted)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .applyTabBarVisibility()
        }
    }

    /// Promotes the level if XP crossed a threshold and shows the banner.
    private func checkPromotion() {
        Task {
            if let promoted = await authVM.autoPromoteLevel(xp: rtdb.xp) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { levelUpTo = promoted }
                try? await Task.sleep(nanoseconds: 3_200_000_000)
                withAnimation(.easeOut(duration: 0.4)) { levelUpTo = nil }
            }
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
                         shadow: .crystalMint, disabled: false) { showFlashcards = true }
                GameCard(icon: "text.append", title: "Sentences", gradient: LinearGradient.crystalShort,
                         shadow: .crystalMint, disabled: false) { showSentences = true }
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

}

// MARK: - Level Up Banner
private struct LevelUpBanner: View {
    let level: String
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(LinearGradient.crystalShort)
                .scaleEffect(pulse ? 1.2 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.4).repeatCount(3), value: pulse)
            VStack(alignment: .leading, spacing: 1) {
                Text("Level Up!").font(.subheadline.bold())
                Text("You've reached \(level.capitalized)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial).cornerRadius(24)
        .overlay(Capsule().strokeBorder(LinearGradient.crystal.opacity(0.5), lineWidth: 1))
        .shadow(color: Color.crystalGold.opacity(0.3), radius: 16, y: 6)
        .onAppear { pulse = true }
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
    @State private var bump = false
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.title2)
            Text(value).font(.title3.bold())
                .contentTransition(.numericText())
                .scaleEffect(bump ? 1.18 : 1)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.ultraThinMaterial).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.25), lineWidth: 1))
        .onChange(of: value) { _, _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3)) { bump = false }
            }
        }
        .animation(.spring(response: 0.4), value: value)
    }
}

// MARK: - Idiom Card
private struct IdiomCard: View {
    let idiom: Idiom
    @State private var showExample = false
    @State private var showTranslation = false
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
            if showExample {
                Text("Example: \(idiom.example)").font(.caption).foregroundColor(.secondary).italic()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if showTranslation {
                Text(idiom.hebrew).font(.subheadline.bold()).foregroundColor(.crystalMint)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 18) {
                Button { withAnimation(.spring(duration: 0.3)) { showExample.toggle() } } label: {
                    Text(showExample ? "Hide example" : "See example").font(.caption.bold())
                        .foregroundStyle(LinearGradient.crystalShort)
                }
                Button { withAnimation(.spring(duration: 0.3)) { showTranslation.toggle() } } label: {
                    Text(showTranslation ? "Hide translation" : "See translation").font(.caption.bold())
                        .foregroundColor(.crystalMint)
                }
            }
        }
        .padding(18).background(.ultraThinMaterial).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1))
        .shadow(color: Color.crystalBlue.opacity(0.08), radius: 12, y: 4)
    }
}

#Preview("Light") { MainTabView(initialTab: 0).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 0).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
