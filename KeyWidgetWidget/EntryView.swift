import SwiftUI
import WidgetKit
import KeyWidgetShared

struct KeyWidgetEntryView: View {
    let entry: KeyWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        let palette = WidgetPalette.for(entry.theme)

        ZStack {
            palette.background.ignoresSafeArea()
            content
                .padding(family == .systemSmall ? 10 : 14)
                .foregroundStyle(palette.foreground)
        }
        .widgetURL(DeepLink.openTabURL(id: entry.tabID))
    }

    @ViewBuilder
    private var content: some View {
        let palette = WidgetPalette.for(entry.theme)
        if entry.isFirstLaunch {
            VStack(alignment: .leading, spacing: 4) {
                Text("Open KeyWidget").font(palette.titleFont).bold()
                Text("to get started").font(palette.bodyFont).opacity(0.7)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if entry.isMissing {
            VStack(alignment: .leading, spacing: 4) {
                Text("⚠︎ Couldn't find").font(palette.bodyFont).opacity(0.8)
                Text(entry.title).font(palette.titleFont).bold().lineLimit(2)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(palette.titleFont).bold().lineLimit(2)
                if family != .systemSmall {
                    Text(entry.preview).font(palette.bodyFont).lineLimit(previewLineLimit)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var previewLineLimit: Int {
        switch family { case .systemMedium: return 3; default: return 10 }
    }
}

struct WidgetPalette {
    let background: Color
    let foreground: Color
    let titleFont: Font
    let bodyFont: Font

    static func `for`(_ theme: Theme) -> WidgetPalette {
        switch theme {
        case .iaWriter:
            return WidgetPalette(
                background: Color(red: 247/255, green: 243/255, blue: 236/255),
                foreground: Color(red: 43/255, green: 39/255, blue: 33/255),
                titleFont: .custom("Iowan Old Style", size: 15),
                bodyFont: .custom("Iowan Old Style", size: 11)
            )
        case .linear:
            return WidgetPalette(
                background: Color(red: 10/255, green: 10/255, blue: 11/255),
                foreground: Color(red: 230/255, green: 230/255, blue: 234/255),
                titleFont: .system(size: 14, weight: .semibold),
                bodyFont: .system(size: 11, weight: .regular)
            )
        case .mono:
            return WidgetPalette(
                background: Color(red: 12/255, green: 12/255, blue: 12/255),
                foreground: Color(red: 212/255, green: 212/255, blue: 199/255),
                titleFont: .system(.body, design: .monospaced).weight(.semibold),
                bodyFont: .system(.caption, design: .monospaced)
            )
        }
    }
}
