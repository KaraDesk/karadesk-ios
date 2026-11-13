import SwiftUI

struct CSATCard: View {
    let message: Message
    let onRate: (Message, Int?, String?) async -> Void

    @State private var remark = ""
    @State private var pending = false
    @State private var openedAt = Date.now
    @FocusState private var remarkFocused: Bool

    struct Face: Identifiable {
        let value: Int
        let emoji: String
        let label: String

        var id: Int { value }
    }

    static let faces: [Face] = [
        Face(value: 1, emoji: "😠", label: String(localized: "csat.terrible", defaultValue: "Terrible", bundle: .module)),
        Face(value: 2, emoji: "🙁", label: String(localized: "csat.bad", defaultValue: "Bad", bundle: .module)),
        Face(value: 3, emoji: "😐", label: String(localized: "csat.ok", defaultValue: "OK", bundle: .module)),
        Face(value: 4, emoji: "😃", label: String(localized: "csat.great", defaultValue: "Great", bundle: .module)),
        Face(value: 5, emoji: "🤩", label: String(localized: "csat.amazing", defaultValue: "Amazing", bundle: .module)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(intro)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(uiColor: .secondarySystemBackground), in: BubbleShape(mine: false, tail: false))

            card
        }
    }

    private var metadata: Message.Metadata? {
        message.metadata
    }

    private var rating: Int? {
        metadata?.rating
    }

    private var expired: Bool {
        rating == nil && (metadata?.expiresAt.map { $0 < openedAt } ?? false)
    }

    private var locked: Bool {
        rating != nil && (metadata?.lockUntil.map { $0 < openedAt } ?? false)
    }

    private var intro: String {
        if let name = Formatting.firstName(metadata?.teammateName), !name.isEmpty {
            return String(localized: "csat.intro.teammate", defaultValue: "Help \(name) understand how they're doing:", bundle: .module)
        }

        return String(localized: "csat.intro", defaultValue: "Help us understand how we're doing:", bundle: .module)
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text(rating == nil ? String(localized: "csat.title", defaultValue: "Rate your conversation", bundle: .module) : Strings.thanksForRating)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            HStack(spacing: 4) {
                ForEach(Self.faces) { face in
                    faceButton(face)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Strings.rateConversation)

            if expired {
                Text(String(localized: "csat.expired", defaultValue: "This rating request has expired.", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let existing = metadata?.remark, !existing.isEmpty {
                Text("“\(existing)”")
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if rating != nil, !locked {
                remarkForm
            }
        }
        .padding(16)
        .frame(width: 272)
        .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .animation(.snappy, value: rating)
        .disabled(pending)
    }

    private func faceButton(_ face: Face) -> some View {
        let selected = rating == face.value
        let disabled = expired || locked

        return Button {
            submit(rating: face.value, remark: nil)
        } label: {
            Text(face.emoji)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background {
                    if selected {
                        Circle().fill(Color(uiColor: .tertiarySystemFill))
                    }
                }
                .opacity(rating != nil && !selected ? 0.35 : 1)
                .scaleEffect(selected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(face.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var remarkForm: some View {
        VStack(spacing: 8) {
            TextField(Strings.addRemark, text: $remark, axis: .vertical)
                .lineLimit(2 ... 5)
                .font(.subheadline)
                .focused($remarkFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 12, style: .continuous))

            Button {
                remarkFocused = false
                submit(rating: nil, remark: remark.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                Text(String(localized: "csat.send", defaultValue: "Send feedback", bundle: .module))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .prominentButton()
            .disabled(remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func submit(rating: Int?, remark: String?) {
        pending = true

        Task {
            await onRate(message, rating, remark)
            pending = false
        }
    }
}
