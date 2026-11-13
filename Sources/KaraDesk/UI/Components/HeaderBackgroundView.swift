import SwiftUI

struct HeaderBackgroundView: View {
    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        switch theme.headerBackground {
        case let .solid(color):
            color
        case let .gradient(from, to):
            LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
        case let .image(url, fallback):
            fallback.overlay {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
            .clipped()
        }
    }
}
