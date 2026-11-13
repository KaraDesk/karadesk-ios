import SwiftUI

struct HomeView: View {
    let store: MessengerStore
    let router: MessengerRouter

    @Environment(\.karaDeskTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                    .padding(.bottom, 18)

                ForEach(store.settings?.homeCards ?? []) { card in
                    HomeCardView(card: card, store: store, router: router)
                }

                if store.settings?.showBranding == true {
                    PoweredBy()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(alignment: .top) {
            HeaderBackgroundView()
                .frame(height: 460)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.55),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea(edges: .top)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollBounceBehavior(.basedOnSize)
        .toolbar {
            BareToolbarItem(placement: .topBarLeading) {
                logo
            }

            if store.settings?.showTeam == true, let team = store.boot?.team, !team.isEmpty {
                BareToolbarItem(placement: .topBarTrailing) {
                    AvatarStack(people: team, size: 34, ring: theme.headerBase)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                CloseButton()
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(theme.headerForeground == .white ? .dark : .light, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                if let greeting = store.settings?.greeting, !greeting.isEmpty {
                    Text(greeting)
                        .opacity(0.7)
                }

                if let intro = store.settings?.intro, !intro.isEmpty {
                    Text(intro)
                }
            }
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(theme.headerForeground)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 8)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var logo: some View {
        let url = colorScheme == .dark ? (store.settings?.darkLogoURL ?? store.settings?.logoURL) : store.settings?.logoURL

        if let url {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(maxWidth: 140, maxHeight: 32, alignment: .leading)
            .accessibilityLabel(store.boot?.space.name ?? "")
        } else if let avatar = store.boot?.space.avatarURL {
            AsyncImage(url: avatar) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityLabel(store.boot?.space.name ?? "")
        } else if let name = store.boot?.space.name {
            Text(name)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.headerForeground)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

private struct HomeCardView: View {
    let card: HomeCard
    let store: MessengerStore
    let router: MessengerRouter

    var body: some View {
        switch card {
        case .messages:
            MessagesCard(store: store, router: router)
        case let .help(help):
            HelpCard(card: help, router: router)
        case let .link(link):
            LinkCard(card: link)
        case let .text(text):
            TextCard(card: text)
        }
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func card() -> some View {
        modifier(CardStyle())
    }
}

private struct CardRow<Accessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory()
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

private struct MessagesCard: View {
    let store: MessengerStore
    let router: MessengerRouter

    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            if store.rules.allowNew {
                Button {
                    router.push(.conversation(id: store.singleOpenConversationID, draft: nil))
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Strings.sendUsAMessage)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(Strings.replyExpectation(store.settings?.availability?.replyTime))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "paperplane")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 44, height: 44)
                            .background(theme.accent, in: Circle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .card()
            }

            if !recent.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text(String(localized: "home.recent_messages", defaultValue: "Recent messages", bundle: .module))
                            .font(.body.weight(.semibold))

                        Spacer()

                        Button(String(localized: "home.see_all", defaultValue: "See all", bundle: .module)) {
                            router.tab = .messages
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, conversation in
                        if index > 0 {
                            Divider()
                        }

                        Button {
                            router.push(.conversation(id: conversation.id, draft: nil))
                        } label: {
                            RecentConversationRow(conversation: conversation, team: store.boot?.team ?? [])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card()
            }
        }
    }

    private var recent: [Conversation] {
        Array(store.conversations.filter { $0.mergedIntoId == nil && $0.lastMessage != nil }.prefix(3))
    }
}

private struct RecentConversationRow: View {
    let conversation: Conversation
    let team: [Person]

    var body: some View {
        HStack(spacing: 14) {
            ConversationAvatar(conversation: conversation, team: team, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(preview)
                    .font(.body.weight(conversation.unread ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if conversation.unread {
                Circle()
                    .fill(.tint)
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var preview: String {
        guard let last = conversation.lastMessage else {
            return ""
        }

        return String(Formatting.markdown(last.body).characters).replacingOccurrences(of: "\n", with: " ")
    }

    private var detail: String {
        let author: String

        switch conversation.lastMessage?.authorType {
        case .contact:
            author = Strings.you
        case .bot:
            author = conversation.lastMessage?.authorName ?? "Kara"
        default:
            author = Formatting.firstName(conversation.lastMessage?.authorName ?? conversation.assignee?.name) ?? Strings.team
        }

        return "\(author) · \(Formatting.relative(conversation.sortDate))"
    }
}

private struct HelpCard: View {
    let card: HomeCard.HelpCard
    let router: MessengerRouter

    @State private var query = ""
    @FocusState private var searching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if card.showSearch {
                HStack(spacing: 10) {
                    TextField(
                        Strings.searchForHelp,
                        text: $query,
                        prompt: Text(Strings.searchForHelp)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                    )
                    .font(.body.weight(.semibold))
                    .focused($searching)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit(search)

                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Strings.searchForHelp)
                }
                .padding(.leading, 16)
                .padding(.trailing, 9)
                .frame(height: 50)
                .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    searching = true
                }
                .padding(10)
            }

            if let title = card.title, !title.isEmpty, !card.articles.isEmpty {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 20)
                    .padding(.top, card.showSearch ? 6 : 18)
                    .padding(.bottom, 2)
            }

            ForEach(card.articles) { article in
                Button {
                    router.push(.article(helpCenterID: card.helpCenter.id, articleID: article.id))
                } label: {
                    HStack(spacing: 14) {
                        Text(article.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, card.articles.isEmpty ? 0 : 8)
        .card()
    }

    private func search() {
        searching = false
        router.search(query)
        query = ""
    }
}

private struct LinkCard: View {
    let card: HomeCard.LinkCard
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(card.url)
        } label: {
            CardRow(title: card.title, subtitle: card.description) {
                Image(systemName: "arrow.up.right")
            }
        }
        .buttonStyle(.plain)
        .card()
    }
}

private struct TextCard: View {
    let card: HomeCard.TextCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = card.title, !title.isEmpty {
                Text(title)
                    .font(.body.weight(.semibold))
            }

            Text(Formatting.markdown(card.body))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .card()
    }
}

struct PoweredBy: View {
    @Environment(\.openURL) private var openURL

    private static let url = URL(string: "https://karadesk.com/?utm_source=messenger&utm_medium=powered_by&utm_campaign=ios")!

    var body: some View {
        Button {
            openURL(Self.url)
        } label: {
            HStack(spacing: 6) {
                KaraDeskMark()
                    .frame(width: 13, height: 13)
                Text(Strings.poweredBy)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.poweredBy)
        .accessibilityAddTraits(.isLink)
    }
}

extension MessengerStore {
    var singleOpenConversationID: Int? {
        guard rules.singleOpen else {
            return nil
        }

        return conversations.first { $0.state != .closed && $0.mergedIntoId == nil }?.id
    }
}
