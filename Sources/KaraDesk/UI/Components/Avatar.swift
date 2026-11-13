import SwiftUI

struct Avatar: View {
    var name: String?
    var url: URL?
    var size: CGFloat = 32
    var showsActiveDot = false

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                if showsActiveDot {
                    Circle()
                        .fill(.green)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .background(Color(uiColor: .systemBackground))
                } else {
                    initials
                }
            }
        } else {
            initials
        }
    }

    private var initials: some View {
        ZStack {
            Color(uiColor: .systemGray5)
            Text(Self.initial(of: name))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    static func initial(of name: String?) -> String {
        guard let first = name?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "?"
        }

        return String(first).uppercased()
    }
}

struct AvatarStack: View {
    let people: [Person]
    var size: CGFloat = 32
    var ring: Color = Color(uiColor: .systemBackground)

    var body: some View {
        HStack(spacing: -size * 0.28) {
            ForEach(people.prefix(3)) { person in
                Avatar(name: person.name, url: person.avatarURL, size: size)
                    .padding(2)
                    .background(ring, in: Circle())
            }
        }
        .accessibilityHidden(true)
    }
}

struct BotAvatar: View {
    var size: CGFloat = 32

    private static let ring = AngularGradient(
        colors: [
            Color(red: 0.486, green: 0.227, blue: 0.929),
            Color(red: 0.859, green: 0.153, blue: 0.467),
            Color(red: 0.961, green: 0.620, blue: 0.043),
            Color(red: 0.486, green: 0.227, blue: 0.929),
        ],
        center: .center,
        startAngle: .degrees(120),
        endAngle: .degrees(480)
    )

    var body: some View {
        let glyph = size * 0.55
        let stroke = 1.5 * glyph / 24

        ZStack {
            Circle().fill(Self.ring)
            Circle()
                .fill(Color(red: 0.039, green: 0.039, blue: 0.039))
                .padding(max(1, size * 0.047))
            SparkleStar()
                .fill(.white)
                .overlay(SparkleStar().stroke(.white, style: StrokeStyle(lineWidth: stroke, lineJoin: .round)))
                .frame(width: glyph, height: glyph)
            SparkleAccents()
                .stroke(.white, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .background(SparkleAccents().fill(.white))
                .frame(width: glyph, height: glyph)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Kara")
    }
}
