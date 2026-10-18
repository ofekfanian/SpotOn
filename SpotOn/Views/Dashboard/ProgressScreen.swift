import SwiftUI
import SwiftData
import Charts

/// Weekly recap, weekly challenge, a six-week activity map and achievements.
struct ProgressScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @ObservedObject private var rtdb = RealtimeDatabaseService.shared
    @Environment(\.colorScheme) private var scheme
    @Query(filter: #Predicate<ReadingPassage> { $0.isCompleted }) private var completedPassages: [ReadingPassage]

    @State private var claiming = false

    private var stats: WeeklyStats { WeeklyStats(words: wordBankVM.words, dailyXP: rtdb.dailyXP) }
    private let challenge = WeeklyChallenge()
    private var achievements: [Achievement] {
        Achievement.all(words: wordBankVM.words, xp: rtdb.xp, streak: rtdb.streak,
                        passagesCompleted: completedPassages.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                weekSummary
                weekChart
                challengeCard
                activityMap
                achievementsGrid
                Spacer(minLength: 24)
            }
            .padding(.horizontal).padding(.top, 8)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()
            }
        }
        .navigationTitle("Your Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: This week

    private var weekSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week").font(.headline)
                Spacer()
                if let trend = stats.trendText {
                    Label("\(trend) XP", systemImage: stats.xp >= stats.lastWeekXP ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.bold())
                        .foregroundColor(stats.xp >= stats.lastWeekXP ? .crystalMint : .orange)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                tile("\(stats.xp)", "XP earned", "star.fill", .crystalGold)
                tile("\(stats.wordsAdded)", "Words added", "plus.circle.fill", .crystalBlue)
                tile("\(stats.wordsMastered)", "Words mastered", "checkmark.seal.fill", .crystalMint)
                tile("\(stats.activeDays)/7", "Active days", "calendar", .orange)
            }
        }
        .dashboardCard()
    }

    private func tile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.bold())
                Text(label).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(color.opacity(0.08)).cornerRadius(14)
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily XP").font(.headline)
            Chart(stats.dailyXP, id: \.day) { entry in
                BarMark(x: .value("Day", entry.day, unit: .day), y: .value("XP", entry.xp))
                    .foregroundStyle(LinearGradient.crystalShort)
                    .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 160)
        }
        .dashboardCard()
    }

    // MARK: Challenge

    private var challengeCard: some View {
        let progress = challenge.progress(in: stats)
        let done = challenge.isComplete(in: stats)
        let claimed = rtdb.claimedChallenges.contains(challenge.weekKey)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: challenge.icon).font(.title2).foregroundColor(.crystalGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Challenge").font(.caption.bold()).foregroundColor(.secondary)
                    Text(challenge.title).font(.headline)
                }
                Spacer()
                Text("+\(challenge.bonus) XP").font(.caption.bold()).foregroundColor(.crystalGold)
            }
            ProgressBar(fraction: Double(progress) / Double(challenge.target))
            HStack {
                Text("\(min(progress, challenge.target)) of \(challenge.target)").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("A new challenge starts every week").font(.caption2).foregroundColor(.secondary)
            }
            if done {
                Button { claim() } label: {
                    Label(claimed ? "Bonus claimed" : "Claim \(challenge.bonus) XP",
                          systemImage: claimed ? "checkmark.circle.fill" : "gift.fill")
                        .font(.subheadline.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(claimed ? AnyShapeStyle(Color.crystalMint) : AnyShapeStyle(LinearGradient.crystal))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(claimed || claiming)
            }
        }
        .dashboardCard(tint: .crystalGold)
    }

    private func claim() {
        guard let uid = authVM.user?.uid else { return }
        claiming = true
        Task {
            try? await rtdb.claimChallenge(week: challenge.weekKey, bonus: challenge.bonus, for: uid)
            SoundService.playCorrect()
            claiming = false
        }
    }

    // MARK: Activity map

    /// Last twelve weeks, one column per week and one row per weekday,
    /// shaded by how much XP was earned that day.
    private var activityMap: some View {
        let weeks: [[Date]] = (0..<12).reversed().map { offset in
            Week.days(of: Calendar.current.date(byAdding: .day, value: -7 * offset, to: Date()) ?? Date())
        }
        let peak = max(rtdb.dailyXP.values.max() ?? 0, 1)
        let today = Calendar.current.startOfDay(for: Date())
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity").font(.headline)
                Spacer()
                Text("Last 12 weeks").font(.caption).foregroundColor(.secondary)
            }
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(weeks.last ?? [], id: \.self) { day in
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                            .frame(width: 14, height: 18)
                    }
                }
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, days in
                    VStack(spacing: 5) {
                        ForEach(days, id: \.self) { day in
                            let xp = rtdb.dailyXP[Week.dayKey(day)] ?? 0
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cellColor(xp: xp, peak: peak, future: day > today))
                                .frame(width: 18, height: 18)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundColor(.secondary)
                ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Color.secondary.opacity(0.15) : Color.crystalMint.opacity(0.25 + 0.75 * level))
                        .frame(width: 12, height: 12)
                }
                Text("More").font(.caption2).foregroundColor(.secondary)
            }
        }
        .dashboardCard(tint: .crystalMint)
    }

    private func cellColor(xp: Int, peak: Int, future: Bool) -> Color {
        if future { return Color.clear }
        guard xp > 0 else { return Color.secondary.opacity(0.15) }
        return Color.crystalMint.opacity(0.25 + 0.75 * Double(xp) / Double(peak))
    }

    // MARK: Achievements

    private var achievementsGrid: some View {
        let unlocked = achievements.filter(\.isUnlocked).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements").font(.headline)
                Spacer()
                Text("\(unlocked)/\(achievements.count)").font(.caption.bold()).foregroundColor(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                ForEach(achievements) { badge in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(badge.isUnlocked ? AnyShapeStyle(LinearGradient.crystal)
                                                           : AnyShapeStyle(Color.secondary.opacity(0.12)))
                                .frame(width: 52, height: 52)
                            Image(systemName: badge.icon).font(.title3)
                                .foregroundColor(badge.isUnlocked ? .white : .secondary.opacity(0.6))
                        }
                        Text(badge.title).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.8)
                        Text(badge.isUnlocked ? badge.detail : "\(min(badge.current, badge.target))/\(badge.target)")
                            .font(.caption2).foregroundColor(.secondary).lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(badge.isUnlocked ? 1 : 0.75)
                }
            }
        }
        .dashboardCard()
    }
}

#Preview("Light") {
    NavigationStack { ProgressScreen() }
        .environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .modelContainer(for: [ReadingPassage.self, PassageWord.self], inMemory: true)
}
