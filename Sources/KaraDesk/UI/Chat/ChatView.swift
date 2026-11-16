import SwiftUI

struct ChatView: View {
    let store: MessengerStore
    let router: MessengerRouter
    @State private var model: ChatModel

    init(store: MessengerStore, router: MessengerRouter, conversationID: Int?, initialDraft: String?) {
        self.store = store
        self.router = router
        _model = State(initialValue: ChatModel(store: store, conversationID: conversationID, draft: initialDraft))
    }

    var body: some View {
        messageList
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    header
                }

                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .task { await model.load() }
        .onDisappear { model.disappear() }
    }

    // MARK: Header

    private var title: String {
        Formatting.firstName(model.conversation?.assignee?.name) ?? store.boot?.space.name ?? Strings.team
    }

    private var header: some View {
        let assignee = model.conversation?.assignee
        let active = assignee?.isActive() ?? false

        return HStack(spacing: 8) {
            if let assignee {
                Avatar(name: assignee.name, url: assignee.avatarURL, size: 30, showsActiveDot: active)
            } else if let team = store.boot?.team, !team.isEmpty {
                AvatarStack(people: team, size: 26)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(active ? Strings.activeNow : Strings.replyExpectation(store.settings?.availability?.replyTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.conversationID == nil {
                        EmptyChat(team: store.boot?.team ?? [])
                    } else if model.messages.isEmpty, let error = model.loadError {
                        ErrorStateView(error: error, title: Strings.conversationLoadFailed) {
                            await model.loadThread()
                        }
                        .padding(.top, 40)
                    } else if model.messages.isEmpty, model.isLoading {
                        ProgressView()
                            .padding(.top, 80)
                    }

                    ForEach(MessageGroup.make(from: model.messages)) { group in
                        MessageGroupView(
                            group: group,
                            onOpenArticle: openArticle,
                            onRate: { message, rating, remark in
                                await model.rate(message, rating: rating, remark: remark)
                            }
                        )
                    }

                    if let author = model.typingAuthor {
                        TypingRow(author: author)
                            .transition(.opacity)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(BottomAnchor.id)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(model.messages.isEmpty ? .top : .bottom)
            .onChange(of: model.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(BottomAnchor.id, anchor: .bottom)
                }
            }
            .onChange(of: model.typingAuthor != nil) {
                withAnimation {
                    proxy.scrollTo(BottomAnchor.id, anchor: .bottom)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func openArticle(_ article: MessageAttachment.Article) {
        router.push(.article(helpCenterID: article.helpCenterID, articleID: article.articleID))
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let mergedInto = model.conversation?.mergedIntoId {
            FooterNotice(text: Strings.continuesElsewhere, action: Strings.continueConversation) {
                router.replaceTop(with: .conversation(id: mergedInto, draft: nil))
            }
        } else if model.isLocked {
            FooterNotice(text: Strings.conversationEnded, action: store.rules.allowNew ? Strings.startNewConversation : nil) {
                router.replaceTop(with: .conversation(id: nil, draft: nil))
            }
        } else {
            Composer(model: model)
        }
    }

    private enum BottomAnchor {
        static let id = "bottom"
    }
}

private struct EmptyChat: View {
    let team: [Person]

    var body: some View {
        VStack(spacing: 10) {
            if !team.isEmpty {
                AvatarStack(people: team, size: 48)
                    .padding(.bottom, 4)
            }

            Text(Strings.askUsAnything)
                .font(.headline)

            Text(Strings.wellReply)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.top, 56)
        .padding(.bottom, 24)
    }
}

private struct FooterNotice: View {
    let text: String
    let action: String?
    let perform: () -> Void

    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let action {
                Button(action: perform) {
                    Text(action)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .prominentButton()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassBar()
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private struct TypingRow: View {
    let author: Message.Author

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if author.kind == .bot {
                BotAvatar(size: 28)
            } else {
                Avatar(name: author.name, url: author.avatarURL, size: 28)
            }

            TypingDots()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground), in: BubbleShape(mine: false, tail: true))

            Spacer()
        }
        .accessibilityElement()
        .accessibilityLabel(Text(String(localized: "chat.typing", defaultValue: "\(author.name ?? Strings.team) is typing", bundle: .module)))
    }
}

private struct TypingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .opacity(animating ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: animating)
            }
        }
        .foregroundStyle(.secondary)
        .onAppear { animating = true }
    }
}
