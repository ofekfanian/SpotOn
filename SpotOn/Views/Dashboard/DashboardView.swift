import SwiftUI
import SwiftData

/// A one-off flashcard session over a fixed list (due reviews, weekly pack).
private struct FlashSession: Identifiable {
    let id = UUID()
    let words: [Word]
}

struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @StateObject private var vm = DashboardViewModel()
    @ObservedObject private var rtdb = RealtimeDatabaseService.shared
    @ObservedObject private var profileImage = ProfileImageStore.shared
    @ObservedObject private var packs = ContentPackService.shared
    @Query(filter: #Predicate<ReadingPassage> { $0.isCompleted }) private var completedPassages: [ReadingPassage]
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var scheme

    @State private var showBlitz = false
    @State private var showFlashcards = false
    @State private var showSnapLearn = false
    @State private var showSentences = false
    @State private var levelUpTo: String? = nil
    @State private var session: FlashSession? = nil
    @State private var unlocked: (badge: Achievement, extra: Int)? = nil

    /// Switches to the Profile tab (the avatar used to push a second copy of it).
    var onProfileTap: () -> Void = {}

    private var canPlayBlitz: Bool { BlitzViewModel.canPlay(with: wordBankVM.words) }

    private var level: String { authVM.userProfile?.level ?? "intermediate" }
    private var name: String {
        if let username = authVM.userProfile?.username, !username.isEmpty { return username }
        return (authVM.user?.email ?? "").components(separatedBy: "@").first?.capitalized ?? "there"
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
                    LevelProgressCard(level: level, xp: rtdb.xp).padding(.horizontal)
                    if !wordBankVM.dueWords.isEmpty {
                        DueReviewBanner(count: wordBankVM.dueWords.count) {
                            session = FlashSession(words: Array(wordBankVM.dueWords.shuffled().prefix(20)))
                        }
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if let wotd = VocabularyService.shared.wordOfTheDay(level: level) {
                        WordOfDayCard(word: wotd, isSaved: wordBankVM.contains(wotd.word)) { save(wordOfDay: wotd) }
                            .padding(.horizontal)
                    }
                    NavigationLink {
                        ProgressScreen().environmentObject(authVM).environmentObject(wordBankVM)
                    } label: {
                        WeeklyRecapCard(stats: WeeklyStats(words: wordBankVM.words, dailyXP: rtdb.dailyXP),
                                        challenge: WeeklyChallenge())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    if let pack = packs.latest {
                        let fresh = pack.asWords.filter { !wordBankVM.contains($0.word) }
                        WeeklyPackCard(pack: pack, newCount: fresh.count) {
                            session = FlashSession(words: fresh.shuffled())
                        }
                        .padding(.horizontal)
                    }
                    idiomSection
                    practiceSection

                    if !canPlayBlitz {
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
            .sheet(isPresented: $showBlitz, onDismiss: checkPromotion) {
                BlitzView(words: wordBankVM.words).environmentObject(authVM)
            }
            .sheet(isPresented: $showFlashcards, onDismiss: checkPromotion) {
                FlashcardsView(level: level)
                    .environmentObject(authVM)
                    .environmentObject(wordBankVM)
            }
            .sheet(isPresented: $showSnapLearn, onDismiss: checkPromotion) {
                NavigationStack {
                    SnapLearnView().environmentObject(authVM).environmentObject(wordBankVM)
                }
            }
            .sheet(isPresented: $showSentences, onDismiss: checkPromotion) {
                SentenceCompletionView(level: level).environmentObject(authVM)
            }
            .sheet(item: $session, onDismiss: checkPromotion) { s in
                FlashcardsView(customDeck: s.words, level: level)
                    .environmentObject(authVM)
                    .environmentObject(wordBankVM)
            }
            .task(id: level) { await vm.load(level: level) }
            .task { await packs.refreshIfNeeded() }
            .onChange(of: wordBankVM.words.count) { _, _ in checkAchievements() }
            .onChange(of: wordBankVM.hasLoaded) { _, _ in checkAchievements() }
            .onChange(of: rtdb.hasLoaded) { _, _ in checkAchievements() }
            .onChange(of: rtdb.streak) { _, _ in checkAchievements() }
            .onChange(of: completedPassages.count) { _, _ in checkAchievements() }
            .animation(.easeInOut(duration: 0.3), value: wordBankVM.dueWords.isEmpty)
            .onChange(of: rtdb.xp) { _, _ in
                // While a game cover is up the banner would be invisible —
                // the cover's onDismiss re-checks instead.
                guard !showBlitz, !showFlashcards, !showSentences, !showSnapLearn, session == nil else { return }
                checkPromotion()
                checkAchievements()
            }
            .overlay(alignment: .top) {
                if let promoted = levelUpTo {
                    LevelUpBanner(level: promoted)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if let unlocked {
                    AchievementBanner(achievement: unlocked.badge, extraCount: unlocked.extra)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.unlocked = nil } }
                }
            }
            .applyTabBarVisibility()
        }
    }

    /// Saves the Word of the Day to the bank (with AI enrichment) for 5 XP.
    private func save(wordOfDay word: Word) {
        guard let uid = authVM.user?.uid else { return }
        var newWord = word
        newWord.context = "Word of the Day"
        Task {
            if await wordBankVM.addWord(newWord, uid: uid) {
                try? await RealtimeDatabaseService.shared.addXP(5, for: uid)
            }
        }
    }

    /// Shows a banner when a badge unlocks. Waits until the word bank has
    /// loaded so existing badges aren't announced as new on launch.
    private func checkAchievements() {
        guard wordBankVM.hasLoaded, rtdb.hasLoaded, unlocked == nil else { return }
        let all = Achievement.all(words: wordBankVM.words, xp: rtdb.xp, streak: rtdb.streak,
                                  passagesCompleted: completedPassages.count)
        let fresh = AchievementTracker.newlyUnlocked(all)
        guard let first = fresh.first else { return }
        SoundService.playCorrect()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { unlocked = (first, fresh.count - 1) }
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            withAnimation(.easeOut(duration: 0.4)) { unlocked = nil }
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
            Button(action: onProfileTap) {
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
                .overlay { GainBadge(event: rtdb.streakGain, suffix: "day", color: .orange) }
            CrystalStatCard(icon: "star.fill", color: .crystalGold, label: "XP", value: "\(rtdb.xp)")
                .overlay { GainBadge(event: rtdb.xpGain, suffix: "XP", color: .crystalGold) }
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
                         shadow: .crystalBlue, disabled: !canPlayBlitz) { showBlitz = true }
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
                .frame(height: 30)   // equal card heights whatever the symbol's shape
            Text(value).font(.title3.bold())
                .lineLimit(1)
                .fixedSize()   // never truncate the number to "…"
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
    }
}

// MARK: - Idiom Card
private struct IdiomCard: View {
    let idiom: Idiom
    @State private var showExample = false
    @State private var showTranslation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            HStack(alignment: .center, spacing: 10) {
                Text("\u{201C}\(idiom.text)\u{201D}").font(.title3.bold()).foregroundStyle(LinearGradient.crystal)
                SpeakButton(text: idiom.text)
            }
            Text(idiom.definition).font(.subheadline).foregroundColor(.secondary)

            if showExample {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.caption2).foregroundColor(.crystalMint)
                        Text("Example").font(.caption2.bold()).foregroundColor(.crystalMint)
                    }
                    Text(idiom.example).font(.caption).foregroundColor(.secondary).italic()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.crystalMint.opacity(0.07)).cornerRadius(10)
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
