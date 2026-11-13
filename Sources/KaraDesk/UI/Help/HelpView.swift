import SwiftUI

struct HelpView: View {
    let store: MessengerStore
    let router: MessengerRouter

    @State private var collections: [HelpCollection]?
    @State private var results: [HelpArticleSummary]?
    @State private var failed = false

    private var helpCenter: HelpCenterReference? {
        store.settings?.helpCenter
    }

    private var query: String {
        router.helpQuery
    }

    var body: some View {
        @Bindable var router = router

        return List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                collectionRows
            } else {
                resultRows
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 8, for: .scrollContent)
        .searchable(text: $router.helpQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: Strings.searchForHelp)
        .overlay {
            if collections == nil, !failed {
                ProgressView()
            }
        }
        .navigationTitle(helpCenter?.name ?? Strings.help)
        .navigationBarTitleDisplayMode(.inline)
        .closeToolbar()
        .task(id: helpCenter?.id) {
            await loadCollections()
        }
        .task(id: query) {
            await search()
        }
    }

    @ViewBuilder
    private var collectionRows: some View {
        if let collections, collections.isEmpty {
            Text(Strings.noArticles)
                .foregroundStyle(.secondary)
        }

        ForEach(collections ?? []) { collection in
            Button {
                guard let helpCenter else {
                    return
                }

                router.push(.collection(helpCenterID: helpCenter.id, collectionID: collection.id, title: collection.name))
            } label: {
                DisclosureRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(collection.name)
                            .font(.body.weight(.medium))

                    if let description = collection.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                        Text(Strings.articleCount(collection.articleCount))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var resultRows: some View {
        if let results, results.isEmpty {
            Text(Strings.noResults)
                .foregroundStyle(.secondary)
        }

        ForEach(results ?? []) { article in
            ArticleRow(article: article) {
                router.push(.article(helpCenterID: helpCenter?.id, articleID: article.id))
            }
        }
    }

    private func loadCollections() async {
        guard let helpCenter else {
            collections = []
            return
        }

        do {
            let page = try await store.help(.collections(helpCenterID: helpCenter.id))
            collections = page.data
                .filter { $0.parentId == nil && $0.articleCount > 0 }
                .sorted { $0.position < $1.position }
        } catch {
            failed = true
            collections = []
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let helpCenter, !term.isEmpty else {
            results = nil
            return
        }

        try? await Task.sleep(for: .milliseconds(250))

        guard !Task.isCancelled else {
            return
        }

        results = (try? await store.help(.search(helpCenterID: helpCenter.id, query: term)))?.data ?? []
    }
}

struct ArticleRow: View {
    let article: HelpArticleSummary
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            DisclosureRow {
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(.body)

                    if let description = article.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CollectionView: View {
    let store: MessengerStore
    let router: MessengerRouter
    let helpCenterID: Int
    let collectionID: Int
    let title: String

    @State private var articles: [HelpArticleSummary]?

    var body: some View {
        List(articles ?? []) { article in
            ArticleRow(article: article) {
                router.push(.article(helpCenterID: helpCenterID, articleID: article.id))
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 8, for: .scrollContent)
        .overlay {
            if articles == nil {
                ProgressView()
            } else if articles?.isEmpty == true {
                Text(Strings.noArticles).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .closeToolbar()
        .task {
            articles = (try? await store.help(.articles(helpCenterID: helpCenterID, collectionID: collectionID)))?.data ?? []
        }
    }
}

struct DisclosureRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
