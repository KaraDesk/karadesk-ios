import SwiftUI

struct Theme: Equatable {
    var accent: Color
    var tint: Color
    var onAccent: Color
    var headerForeground: Color
    var headerBackground: HeaderBackground
    var colorScheme: ColorScheme?

    enum HeaderBackground: Equatable {
        case solid(Color)
        case gradient(Color, Color)
        case image(URL, fallback: Color)
    }

    var headerBase: Color {
        switch headerBackground {
        case let .solid(color):
            color
        case let .gradient(from, _):
            from
        case let .image(_, fallback):
            fallback
        }
    }

    static let standard = Theme(
        accent: Color(hex: "#111111") ?? .black,
        tint: .primary,
        onAccent: .white,
        headerForeground: .white,
        headerBackground: .solid(Color(hex: "#111111") ?? .black),
        colorScheme: nil
    )

    init(accent: Color, tint: Color, onAccent: Color, headerForeground: Color, headerBackground: HeaderBackground, colorScheme: ColorScheme?) {
        self.accent = accent
        self.tint = tint
        self.onAccent = onAccent
        self.headerForeground = headerForeground
        self.headerBackground = headerBackground
        self.colorScheme = colorScheme
    }

    init(settings: MessengerSettings, dark: Bool) {
        let accentHex = (dark ? settings.dark.color : nil) ?? settings.color
        let accent = Color(hex: accentHex) ?? Self.standard.accent
        let background = settings.background
        let overrides = dark ? settings.dark.background : nil
        let kind = overrides?.type ?? background.kind
        let base = Color(hex: overrides?.color ?? background.color ?? accentHex) ?? accent

        let header: HeaderBackground
        switch kind {
        case .solid:
            header = .solid(base)
        case .gradient:
            let from = Color(hex: overrides?.gradientFrom ?? background.gradientFrom ?? accentHex) ?? accent
            let to = Color(hex: overrides?.gradientTo ?? background.gradientTo ?? accentHex) ?? accent
            header = .gradient(from, to)
        case .image:
            let url = dark ? (settings.darkBackgroundImageURL ?? background.imageURL) : background.imageURL
            header = url.map { .image($0, fallback: base) } ?? .solid(base)
        }

        let headerText = (dark ? settings.dark.headerText : nil) ?? settings.headerText
        let headerForeground: Color
        switch headerText {
        case .light:
            headerForeground = .white
        case .dark:
            headerForeground = .black
        case .auto:
            headerForeground = Color.readableForeground(on: overrides?.color ?? background.color ?? background.gradientFrom ?? accentHex)
        }

        let scheme: ColorScheme? = switch settings.theme {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }

        let luminance = Color.luminance(hex: accentHex) ?? 0.5
        let tint: Color = if dark, luminance < 0.12 {
            .white
        } else if !dark, luminance > 0.75 {
            .black
        } else {
            accent
        }

        self.init(
            accent: accent,
            tint: tint,
            onAccent: Color.readableForeground(on: accentHex),
            headerForeground: headerForeground,
            headerBackground: header,
            colorScheme: scheme
        )
    }
}

extension Color {
    init?(hex: String) {
        guard let components = Self.rgb(hex: hex) else {
            return nil
        }

        self.init(red: components.red, green: components.green, blue: components.blue)
    }

    static func readableForeground(on hex: String) -> Color {
        guard let luminance = luminance(hex: hex) else {
            return .white
        }

        return luminance > 0.45 ? .black : .white
    }

    static func luminance(hex: String) -> Double? {
        guard let rgb = rgb(hex: hex) else {
            return nil
        }

        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    private static func rgb(hex: String) -> (red: Double, green: Double, blue: Double)? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("#") {
            value.removeFirst()
        }

        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }

        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            return nil
        }

        return (
            Double((number >> 16) & 0xFF) / 255,
            Double((number >> 8) & 0xFF) / 255,
            Double(number & 0xFF) / 255
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.standard
}

extension EnvironmentValues {
    var karaDeskTheme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
