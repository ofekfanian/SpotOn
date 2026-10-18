import WidgetKit
import SwiftUI

// MARK: - Timeline
struct IdiomEntry: TimelineEntry {
    let date: Date
    let text: String
    let definition: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> IdiomEntry {
        IdiomEntry(date: Date(), text: "Hit the nail on the head", definition: "To be exactly right")
    }
    func getSnapshot(in context: Context, completion: @escaping (IdiomEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<IdiomEntry>) -> Void) {
        // Refresh right after midnight, when the idiom of the day changes.
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400 + 60)
        completion(Timeline(entries: [load()], policy: .after(tomorrow)))
    }

    /// Prefers the idiom the app cached in the shared App Group (matches the
    /// user's level). Without an App Group (free Personal Team) it picks the
    /// same day's idiom from its own copy of idioms.json.
    private func load() -> IdiomEntry {
        let d = UserDefaults(suiteName: "group.com.spoton.shared")
        if let text = d?.string(forKey: "widgetIdiomText") {
            return IdiomEntry(date: Date(), text: text, definition: d?.string(forKey: "widgetIdiomDef") ?? "")
        }
        if let idiom = BundledIdioms.today() {
            return IdiomEntry(date: Date(), text: idiom.text, definition: idiom.definition)
        }
        return IdiomEntry(date: Date(), text: "Open SpotOn for today's idiom", definition: "")
    }
}

/// Same rotation as the app's IdiomService: day-of-era index modulo the pool.
private enum BundledIdioms {
    struct Entry: Decodable { let text: String; let definition: String }

    static func today(level: String = "intermediate") -> Entry? {
        guard let url = Bundle.main.url(forResource: "idioms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([String: [Entry]].self, from: data),
              let pool = all[level] ?? all.values.first, !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return pool[day % pool.count]
    }
}

// MARK: - View
struct SpotOnWidgetEntryView: View {
    var entry: IdiomEntry
    private let accent = LinearGradient(
        colors: [Color(red: 0.36, green: 0.66, blue: 0.85), Color(red: 0.32, green: 0.79, blue: 0.66)],
        startPoint: .leading, endPoint: .trailing)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                Text("Idiom of the Day").font(.caption2.bold())
            }
            .foregroundStyle(accent)
            Text("\u{201C}\(entry.text)\u{201D}").font(.headline).minimumScaleFactor(0.6)
            if !entry.definition.isEmpty {
                Text(entry.definition).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget
struct SpotOnWidget: Widget {
    let kind = "SpotOnWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SpotOnWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Idiom of the Day")
        .description("Today's English idiom from SpotOn.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
