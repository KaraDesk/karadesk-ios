import Foundation
import SwiftUI

enum Formatting {
    static func shortTime(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current

        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))

        switch seconds {
        case ..<60:
            return String(localized: "time.now", defaultValue: "now", bundle: .module)
        case ..<3600:
            return "\(Int(seconds / 60))m"
        case ..<86_400:
            return "\(Int(seconds / 3600))h"
        case ..<604_800:
            return "\(Int(seconds / 86_400))d"
        default:
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func byteCount(_ bytes: Int) -> String {
        Int64(bytes).formatted(.byteCount(style: .file))
    }

    static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    static func firstName(_ name: String?) -> String? {
        name?.split(separator: " ").first.map(String.init)
    }
}
