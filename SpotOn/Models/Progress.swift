import Foundation

// MARK: - Week math

/// Calendar weeks follow the device's first weekday (Sunday in Israel).
enum Week {
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = Calendar.current.firstWeekday
        return cal
    }

    static func start(of date: Date = Date()) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// The seven days of the week containing `date`, first weekday first.
    static func days(of date: Date = Date()) -> [Date] {
        let first = start(of: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    /// Stable key like "2026-W42", used to claim the weekly challenge once.
    static func key(for date: Date = Date()) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    static func weekNumber(for date: Date = Date()) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    static func dayKey(_ date: Date) -> String { DateFormatter.spotDate.string(from: date) }
}

// MARK: - Weekly stats

struct WeeklyStats {
    let xp: Int
    let lastWeekXP: Int          // last week, up to the same weekday
    let wordsAdded: Int
    let wordsMastered: Int
    let activeDays: Int
    /// XP per day, aligned with `Week.days()`.
    let dailyXP: [(day: Date, xp: Int)]

    init(words: [Word], dailyXP map: [String: Int], now: Date = Date()) {
        let days = Week.days(of: now)
        let start = Week.start(of: now)
        let lastWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: start) ?? start
        dailyXP = days.map { ($0, map[Week.dayKey($0)] ?? 0) }
        xp = dailyXP.reduce(0) { $0 + $1.xp }
        // Compare like with like: last week up to the same weekday as today,
        // so Sunday morning isn't measured against a whole finished week.
        let elapsed = days.filter { $0 <= now }.count
        lastWeekXP = Week.days(of: lastWeekStart).prefix(max(elapsed, 1))
            .reduce(0) { $0 + (map[Week.dayKey($1)] ?? 0) }
        wordsAdded = words.filter { $0.createdAt >= start }.count
        wordsMastered = words.filter { ($0.masteredAt ?? .distantPast) >= start }.count
        // A day counts as active when you earned XP or added a word.
        let wordDays = Set(words.filter { $0.createdAt >= start }.map { Week.dayKey($0.createdAt) })
        activeDays = days.filter { (map[Week.dayKey($0)] ?? 0) > 0 || wordDays.contains(Week.dayKey($0)) }.count
    }

    /// "+25%" vs last week, nil when there's nothing to compare against.
    var trendText: String? {
        guard lastWeekXP > 0 else { return nil }
        let change = Int((Double(xp - lastWeekXP) / Double(lastWeekXP) * 100).rounded())
        return change >= 0 ? "+\(change)%" : "\(change)%"
    }
}

// MARK: - Weekly challenge

/// One goal per week, rotating between three kinds so it stays fresh.
struct WeeklyChallenge {
    enum Kind { case addWords, earnXP, activeDays }

    let kind: Kind
    let target: Int
    let bonus = 100
    let weekKey: String

    init(now: Date = Date()) {
        weekKey = Week.key(for: now)
        switch Week.weekNumber(for: now) % 3 {
        case 0:  kind = .addWords;   target = 20
        case 1:  kind = .earnXP;     target = 400
        default: kind = .activeDays; target = 5
        }
    }

    var title: String {
        switch kind {
        case .addWords:   return "Add \(target) new words"
        case .earnXP:     return "Earn \(target) XP"
        case .activeDays: return "Practice on \(target) different days"
        }
    }

    var icon: String {
        switch kind {
        case .addWords:   return "text.badge.plus"
        case .earnXP:     return "star.fill"
        case .activeDays: return "calendar"
        }
    }

    func progress(in stats: WeeklyStats) -> Int {
        switch kind {
        case .addWords:   return stats.wordsAdded
        case .earnXP:     return stats.xp
        case .activeDays: return stats.activeDays
        }
    }

    func isComplete(in stats: WeeklyStats) -> Bool { progress(in: stats) >= target }
}

// MARK: - Achievements

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let current: Int
    let target: Int

    var isUnlocked: Bool { current >= target }
    var fraction: Double { min(1, Double(current) / Double(max(target, 1))) }

    /// All badges, computed from live stats (nothing extra to store).
    static func all(words: [Word], xp: Int, streak: Int, passagesCompleted: Int) -> [Achievement] {
        let total = words.count
        let mastered = words.filter(\.isMastered).count
        return [
            .init(id: "words10",   title: "First Steps",    detail: "Save 10 words",            icon: "leaf.fill",            current: total,    target: 10),
            .init(id: "words50",   title: "Collector",      detail: "Save 50 words",            icon: "books.vertical.fill",  current: total,    target: 50),
            .init(id: "words200",  title: "Lexicon",        detail: "Save 200 words",           icon: "character.book.closed.fill", current: total, target: 200),
            .init(id: "master10",  title: "Sharp Mind",     detail: "Master 10 words",          icon: "checkmark.seal.fill",  current: mastered, target: 10),
            .init(id: "master100", title: "Word Master",    detail: "Master 100 words",         icon: "crown.fill",           current: mastered, target: 100),
            .init(id: "streak3",   title: "Warming Up",     detail: "3-day streak",             icon: "flame",                current: streak,   target: 3),
            .init(id: "streak7",   title: "On Fire",        detail: "7-day streak",             icon: "flame.fill",           current: streak,   target: 7),
            .init(id: "streak30",  title: "Unstoppable",    detail: "30-day streak",            icon: "bolt.heart.fill",      current: streak,   target: 30),
            .init(id: "xp500",     title: "Rising Star",    detail: "Earn 500 XP",              icon: "star.fill",            current: xp,       target: 500),
            .init(id: "xp2000",    title: "Superstar",      detail: "Earn 2,000 XP",            icon: "sparkles",             current: xp,       target: 2000),
            .init(id: "read3",     title: "Bookworm",       detail: "Complete 3 reading passages", icon: "book.pages.fill",   current: passagesCompleted, target: 3),
            .init(id: "read15",    title: "Avid Reader",    detail: "Complete every passage",   icon: "graduationcap.fill",   current: passagesCompleted, target: 15),
        ]
    }
}

/// Remembers which badges the user has already been congratulated on, so a
/// banner appears only the moment a new one unlocks.
enum AchievementTracker {
    private static let key = "seenAchievements"

    /// Returns badges unlocked since the last call and marks them as seen.
    /// The very first call only records the current state (no banner flood).
    static func newlyUnlocked(_ achievements: [Achievement]) -> [Achievement] {
        let defaults = UserDefaults.standard
        let unlocked = achievements.filter(\.isUnlocked)
        guard let seen = defaults.stringArray(forKey: key) else {
            defaults.set(unlocked.map(\.id), forKey: key)
            return []
        }
        let fresh = unlocked.filter { !seen.contains($0.id) }
        if !fresh.isEmpty { defaults.set(seen + fresh.map(\.id), forKey: key) }
        return fresh
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: key) }
}
