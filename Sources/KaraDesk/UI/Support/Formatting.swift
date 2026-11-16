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
        guard bytes > 0 else {
            return ""
        }

        if bytes < 1024 {
            return "\(bytes) B"
        }

        if bytes < 1024 * 1024 {
            return "\(Int((Double(bytes) / 1024).rounded())) KB"
        }

        let megabytes = String(format: "%.1f", Double(bytes) / (1024 * 1024))
        return "\(megabytes.hasSuffix(".0") ? String(megabytes.dropLast(2)) : megabytes) MB"
    }

    static func duration(_ seconds: Double) -> String? {
        guard seconds.isFinite, seconds > 0 else {
            return nil
        }

        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }

        return String(format: "%d:%02d", minutes, remainder)
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
