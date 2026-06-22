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
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [load()], policy: .after(next)))
    }
    // Reads the idiom the app cached in the shared App Group.
    private func load() -> IdiomEntry {
        let d = UserDefaults(suiteName: "group.com.spoton.shared")
        return IdiomEntry(date: Date(),
                          text: d?.string(forKey: "widgetIdiomText") ?? "Open SpotOn for today's idiom",
                          definition: d?.string(forKey: "widgetIdiomDef") ?? "")
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
