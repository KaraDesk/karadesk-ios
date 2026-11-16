import SwiftUI

struct ConversationListView: View {
    let store: MessengerStore
    let router: MessengerRouter

    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        Group {
            if store.conversations.isEmpty, let error = store.conversationsError {
                ErrorStateView(error: error, title: Strings.messagesLoadFailed) {
                    await store.refreshConversations()
                }
                .frame(maxHeight: .infinity)
            } else if store.conversations.isEmpty {
                ContentUnavailableView {
                    Label(Strings.noConversations, systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text(Strings.noConversationsDetail)
                } actions: {
                    newConversationButton
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.conversations) { conversation in
                        Button {
                            router.push(.conversation(id: conversation.id, draft: nil))
                        } label: {
                            ConversationRow(conversation: conversation, team: store.boot?.team ?? [])
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await store.refreshConversations()
                }
                .safeAreaInset(edge: .bottom) {
                    newConversationButton
                        .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle(Strings.messages)
        .navigationBarTitleDisplayMode(.inline)
        .closeToolbar()
    }

    @ViewBuilder
    private var newConversationButton: some View {
        if store.rules.allowNew {
            Button {
                router.push(.conversation(id: store.singleOpenConversationID, draft: nil))
            } label: {
                Label(Strings.sendUsAMessage, systemImage: "paperplane.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .prominentButton()
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let team: [Person]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(conversation.unread ? .semibold : .medium))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(Formatting.shortTime(conversation.sortDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(conversation.unread ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if conversation.unread {
                        Circle()
                            .fill(.tint)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        ConversationAvatar(conversation: conversation, team: team, size: 40)
    }

    private var title: String {
        if let name = conversation.assignee?.name {
            return name
        }

        if let author = conversation.lastMessage, author.authorType != .contact, let name = author.authorName {
            return name
        }

        return conversation.title ?? Strings.team
    }

    private var preview: String {
        guard let last = conversation.lastMessage else {
            return ""
        }

        let body = String(Formatting.markdown(last.body).characters)
            .replacingOccurrences(of: "\n", with: " ")

        return last.authorType == .contact ? "\(Strings.you): \(body)" : body
    }
}

struct ConversationAvatar: View {
    let conversation: Conversation
    let team: [Person]
    var size: CGFloat = 40

    var body: some View {
        if conversation.lastMessage?.authorType == .bot {
            BotAvatar(size: size)
        } else if let assignee = conversation.assignee {
            Avatar(name: assignee.name, url: assignee.avatarURL, size: size)
        } else if let first = team.first {
            Avatar(name: first.name, url: first.avatarURL, size: size)
        } else {
            Avatar(name: nil, url: nil, size: size)
        }
    }
}
