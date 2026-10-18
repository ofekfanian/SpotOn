import SwiftUI

// Cards shown on the dashboard. Each one is self-contained and styled like
// the rest of the app: frosted material, crystal gradients, 18–20pt corners.

private struct CardStyle: ViewModifier {
    var tint: Color = .crystalBlue
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(tint.opacity(0.25), lineWidth: 1))
    }
}

extension View {
    func dashboardCard(tint: Color = .crystalBlue) -> some View { modifier(CardStyle(tint: tint)) }
}

// MARK: - Level progress

/// Ring showing how far the user is through the current level.
struct LevelProgressCard: View {
    let level: String
    let xp: Int

    private var bounds: (lower: Int, upper: Int)? {
        switch LevelSystem.xpLevel(xp) {
        case "beginner":     return (0, 600)
        case "intermediate": return (600, 1800)
        default:             return nil
        }
    }

    private var fraction: Double {
        guard let b = bounds else { return 1 }
        return min(1, max(0, Double(xp - b.lower) / Double(b.upper - b.lower)))
    }

    private var nextLevel: String? {
        let rank = LevelSystem.rank(level) + 1
        return LevelSystem.order.indices.contains(rank) ? LevelSystem.order[rank] : nil
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 7)
                Circle().trim(from: 0, to: fraction)
                    .stroke(LinearGradient.crystal, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: fraction)
                Text("\(Int(fraction * 100))%").font(.caption.bold())
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(level.capitalized).font(.headline)
                if let toNext = LevelSystem.xpToNext(xp), let next = nextLevel {
                    Text("\(toNext) XP to \(next.capitalized)").font(.subheadline).foregroundColor(.secondary)
                } else {
                    Text("Top level reached. Keep your streak going!").font(.subheadline).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis").font(.title3).foregroundStyle(LinearGradient.crystalShort)
        }
        .dashboardCard()
    }
}

// MARK: - Reviews due

struct DueReviewBanner: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.clockwise.circle.fill").font(.title2).foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) word\(count == 1 ? "" : "s") due for review").font(.subheadline.bold())
                    Text("Review now to lock them into memory").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("Review").font(.caption.bold()).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.orange).cornerRadius(10)
            }
            .dashboardCard(tint: .orange)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Word of the Day

struct WordOfDayCard: View {
    let word: Word
    let isSaved: Bool
    let onSave: () -> Void
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Word of the Day", systemImage: "textformat.abc").font(.caption.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
                Spacer()
                Text(word.level.capitalized).font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.crystalMint.opacity(0.12)).foregroundColor(.crystalMint).cornerRadius(8)
            }
            HStack(spacing: 10) {
                Text(word.word).font(.title2.bold()).foregroundStyle(LinearGradient.crystal)
                SpeakButton(text: word.word)
                Spacer()
            }
            Button { withAnimation(.spring(duration: 0.3)) { revealed.toggle() } } label: {
                Group {
                    if revealed {
                        Text(word.translation).font(.headline).foregroundColor(.crystalMint)
                            .environment(\.layoutDirection, .rightToLeft)
                    } else {
                        Label("Tap to see the translation", systemImage: "eye").font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onSave) {
                Label(isSaved ? "In your Word Bank" : "Add to Word Bank",
                      systemImage: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(isSaved ? AnyShapeStyle(Color.crystalMint) : AnyShapeStyle(LinearGradient.crystalShort))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isSaved)
        }
        .dashboardCard(tint: .crystalMint)
    }
}

// MARK: - Weekly recap

struct WeeklyRecapCard: View {
    let stats: WeeklyStats
    let challenge: WeeklyChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Your Week", systemImage: "calendar").font(.caption.bold())
                    .foregroundStyle(LinearGradient.crystalShort)
                Spacer()
                if let trend = stats.trendText {
                    Text("\(trend) XP vs last week").font(.caption2.bold())
                        .foregroundColor(stats.xp >= stats.lastWeekXP ? .crystalMint : .orange)
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: 16) {
                metric("\(stats.xp)", "XP")
                metric("\(stats.wordsAdded)", "new words")
                metric("\(stats.wordsMastered)", "mastered")
                Spacer()
                WeekBars(values: stats.dailyXP.map(\.xp))
                    .frame(width: 96, height: 40)
            }

            let progress = challenge.progress(in: stats)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: challenge.icon).font(.caption).foregroundColor(.crystalGold)
                    Text("Challenge: \(challenge.title)").font(.caption.bold())
                    Spacer()
                    Text("\(min(progress, challenge.target))/\(challenge.target)").font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
                ProgressBar(fraction: Double(progress) / Double(challenge.target))
            }
        }
        .dashboardCard(tint: .crystalGold)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold()).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

/// Seven tiny bars, one per day of the week.
struct WeekBars: View {
    let values: [Int]
    var body: some View {
        let peak = max(values.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 3)
                    .fill(v > 0 ? AnyShapeStyle(LinearGradient.crystalShort) : AnyShapeStyle(Color.secondary.opacity(0.18)))
                    .frame(height: max(4, CGFloat(v) / CGFloat(peak) * 40))
            }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(LinearGradient.crystal)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
                    .animation(.spring(response: 0.6), value: fraction)
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Weekly pack

struct WeeklyPackCard: View {
    let pack: ContentPack
    let newCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(LinearGradient.crystal).frame(width: 52, height: 52)
                    Image(systemName: pack.icon).font(.title3.bold()).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEW THIS WEEK").font(.caption2.bold()).foregroundColor(.crystalGold)
                    Text(pack.title).font(.headline)
                    Text(newCount > 0 ? "\(newCount) new words to learn" : "All words learned. Nice work!")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
            }
            .dashboardCard(tint: .crystalGold)
        }
        .buttonStyle(.plain)
        .disabled(newCount == 0)
    }
}

// MARK: - Achievement banner

struct AchievementBanner: View {
    let achievement: Achievement
    let extraCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon).font(.title2).foregroundColor(.white)
                .frame(width: 44, height: 44).background(LinearGradient.crystal).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked!").font(.caption.bold()).foregroundColor(.crystalGold)
                Text(achievement.title).font(.subheadline.bold())
                Text(extraCount > 0 ? "\(achievement.detail) · +\(extraCount) more" : achievement.detail)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial).cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(LinearGradient.crystal.opacity(0.5), lineWidth: 1))
        .shadow(color: Color.crystalGold.opacity(0.3), radius: 16, y: 6)
        .padding(.horizontal, 24)
    }
}
