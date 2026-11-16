import SwiftUI

struct MessageGroup: Identifiable {
    let id: String
    let author: Message.Author
    let messages: [Message]

    var isMine: Bool {
        author.kind == .contact
    }

    static func make(from messages: [Message]) -> [MessageGroup] {
        var groups: [MessageGroup] = []

        for message in messages where message.isRenderable {
            if let last = groups.last,
               last.author.kind == message.author.kind,
               last.author.name == message.author.name,
               message.kind != .csat,
               last.messages.last?.kind != .csat,
               message.createdAt.timeIntervalSince(last.messages.last?.createdAt ?? .distantPast) < 300 {
                groups[groups.count - 1] = MessageGroup(id: last.id, author: last.author, messages: last.messages + [message])
            } else {
                groups.append(MessageGroup(id: message.id, author: message.author, messages: [message]))
            }
        }

        return groups
    }
}

extension Message {
    var isRenderable: Bool {
        switch kind {
        case .comment, .replyTime:
            return !body.isEmpty || !attachments.isEmpty || hasComponents
        case .csat:
            return metadata != nil
        case .other:
            return false
        }
    }

    var hasComponents: Bool {
        components.contains(where: \.isRenderable)
    }
}

struct MessageGroupView: View {
    let group: MessageGroup
    let onOpenArticle: (MessageAttachment.Article) -> Void
    let onRate: (Message, Int?, String?) async -> Void
    let components: ComponentHandlers

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if group.isMine {
                Spacer(minLength: 48)
            } else {
                avatar
            }

            VStack(alignment: group.isMine ? .trailing : .leading, spacing: 4) {
                if !group.isMine {
                    authorLabel
                }

                ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                    MessageView(
                        message: message,
                        mine: group.isMine,
                        tail: index == group.messages.count - 1,
                        onOpenArticle: onOpenArticle,
                        onRate: onRate,
                        components: components
                    )
                }

                if let last = group.messages.last {
                    Text(Formatting.clock(last.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }

            if !group.isMine {
                Spacer(minLength: 32)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if group.author.kind == .bot {
            BotAvatar(size: 28)
        } else {
            Avatar(name: group.author.name, url: group.author.avatarURL, size: 28)
        }
    }

    private var authorLabel: some View {
        HStack(spacing: 6) {
            Text(group.author.name ?? Strings.team)
                .font(.caption)
                .foregroundStyle(.secondary)

            if group.author.kind == .bot {
                Text(Strings.aiAgent)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct MessageView: View {
    let message: Message
    let mine: Bool
    let tail: Bool
    let onOpenArticle: (MessageAttachment.Article) -> Void
    let onRate: (Message, Int?, String?) async -> Void
    let components: ComponentHandlers

    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
            if message.kind == .csat {
                CSATCard(message: message, onRate: onRate)
            } else {
                if !message.body.isEmpty {
                    Text(Formatting.markdown(message.body))
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(mine ? theme.onAccent : .primary)
                        .tint(mine ? theme.onAccent : theme.tint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            mine ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color(uiColor: .secondarySystemBackground)),
                            in: BubbleShape(mine: mine, tail: tail && message.attachments.isEmpty && !message.hasComponents)
                        )
                }

                if !message.attachments.isEmpty {
                    MessageAttachmentsView(attachments: message.attachments, mine: mine, onOpenArticle: onOpenArticle)
                }

                if !mine, message.hasComponents {
                    MessageComponentsView(message: message, handlers: components)
                }
            }
        }
    }
}

struct BubbleShape: Shape {
    let mine: Bool
    let tail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let small: CGFloat = 5

        return UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: !mine && tail ? small : radius,
            bottomTrailingRadius: mine && tail ? small : radius,
            topTrailingRadius: radius,
            style: .continuous
        )
        .path(in: rect)
    }
}
