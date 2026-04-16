import Foundation
import WidgetKit
import KeyWidgetShared

struct KeyWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let preview: String
    let theme: Theme
    let tabID: UUID
    let isMissing: Bool
    let isFirstLaunch: Bool
}
