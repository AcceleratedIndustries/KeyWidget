import SwiftUI
import WidgetKit

struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

struct PlaceholderView: View {
    var entry: PlaceholderEntry
    var body: some View { Text("KeyWidget").padding() }
}

@main
struct KeyWidgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeyWidgetWidget", provider: PlaceholderProvider()) { entry in
            PlaceholderView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
