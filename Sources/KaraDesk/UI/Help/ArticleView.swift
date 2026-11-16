import SwiftUI

struct ArticleView: View {
    let store: MessengerStore
    let helpCenterID: Int?
    let articleID: Int

    @State private var article: HelpArticle?
    @State private var failed = false
    @State private var loadError: KaraDeskError?
    @State private var reaction: ArticleReaction?
    @State private var browserURL: URL?

    private var helpCenter: HelpCenterReference? {
        store.settings?.helpCenter(id: helpCenterID)
    }

    var body: some View {
        ScrollView {
            if let article {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(article.title)
                            .font(.largeTitle)
                            .accessibilityAddTraits(.isHeader)

                        if let description = article.description, !description.isEmpty {
                            Text(description)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    byline(for: article)

                    if let body = article.body {
                        RichText(node: body, baseURL: helpCenter?.url)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let loadError, loadError.isRetryable {
                ErrorStateView(error: loadError, title: Strings.articleLoadFailed) {
                    await load()
                }
                .padding(.top, 40)
            } else if failed {
                ContentUnavailableView(Strings.articleUnavailable, systemImage: "doc.text.magnifyingglass")
                    .padding(.top, 80)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if article != nil, helpCenter?.articleReactions == true {
                reactions
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .closeToolbar()
        .toolbar(.hidden, for: .tabBar)
        .environment(\.openURL, OpenURLAction { url in
            browserURL = url
            return .handled
        })
        .sheet(item: $browserURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func byline(for article: HelpArticle) -> some View {
        let author = article.author.flatMap { Formatting.firstName($0.name) }
        let updated = article.updatedAt.map {
            String(localized: "article.updated", defaultValue: "Updated \($0.formatted(date: .long, time: .omitted))", bundle: .module)
        }

        if author != nil || updated != nil {
            HStack(spacing: 12) {
                if let person = article.author {
                    Avatar(name: person.name, url: person.avatarURL, size: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let author {
                        Text(String(localized: "article.written_by", defaultValue: "Written by \(author)", bundle: .module))
                    }

                    if let updated {
                        Text(updated)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var reactions: some View {
        VStack(spacing: 10) {
            Text(reaction == nil ? Strings.wasThisHelpful : Strings.thanksForReaction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            HStack(spacing: 28) {
                ForEach(ArticleReaction.allCases, id: \.self) { option in
                    Button {
                        reaction = option
                        Task { await store.react(option, articleID: articleID) }
                    } label: {
                        Text(option.emoji)
                            .font(.system(size: 32))
                            .opacity(reaction == nil || reaction == option ? 1 : 0.35)
                            .scaleEffect(reaction == option ? 1.15 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(option.rawValue))
                    .accessibilityAddTraits(reaction == option ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .animation(.spring(duration: 0.25), value: reaction)
    }

    private func load() async {
        guard let id = helpCenterID ?? store.settings?.helpCenter?.id else {
            failed = true
            return
        }

        loadError = nil

        do {
            article = try await store.help(.article(helpCenterID: id, articleID: articleID))
        } catch where !error.isCancelled {
            loadError = error
            failed = true
        } catch {
            return
        }
    }
}

private extension ArticleReaction {
    var emoji: String {
        switch self {
        case .sad: "😞"
        case .neutral: "😐"
        case .happy: "😃"
        }
    }
}
