import SwiftUI
import WidgetKit

@main
struct KeyWidgetWidget: Widget {
    let kind: String = "KeyWidgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeyWidgetProvider()) { entry in
            KeyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("KeyWidget")
        .description("Your currently active cheat sheet, glanceable on the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
