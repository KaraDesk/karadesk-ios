import SwiftUI

struct HelpView: View {
    let store: MessengerStore
    let router: MessengerRouter

    @State private var collections: [HelpCollection]?
    @State private var results: [HelpArticleSummary]?
    @State private var loadError: KaraDeskError?
    @State private var searchError: KaraDeskError?

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
            if !isSearching, let loadError, collections?.isEmpty != false {
                ErrorStateView(error: loadError, title: Strings.helpLoadFailed) {
                    await loadCollections()
                }
            } else if collections == nil, loadError == nil {
                ProgressView()
            }
        }
        .navigationTitle(Strings.help)
        .navigationBarTitleDisplayMode(.inline)
        .closeToolbar()
        .task(id: helpCenter?.id) {
            await loadCollections()
        }
        .task(id: query) {
            await search()
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var collectionRows: some View {
        if let collections, collections.isEmpty, loadError == nil {
            Text(Strings.noArticles)
                .foregroundStyle(.secondary)
        }

        ForEach(collections ?? []) { collection in
            CollectionRow(collection: collection) {
                guard let helpCenter else {
                    return
                }

                router.push(.collection(helpCenterID: helpCenter.id, collectionID: collection.id, title: collection.name))
            }
        }
    }

    @ViewBuilder
    private var resultRows: some View {
        if let searchError {
            InlineErrorRow(error: searchError) {
                await runSearch()
            }
        } else if let results, results.isEmpty {
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

        loadError = nil

        do {
            let page = try await store.help(.collections(helpCenterID: helpCenter.id))
            collections = page.data.withTotals().filter { $0.parentId == nil }
        } catch where !error.isCancelled {
            loadError = error
        } catch {
            return
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard helpCenter != nil, !term.isEmpty else {
            results = nil
            searchError = nil
            return
        }

        try? await Task.sleep(for: .milliseconds(250))

        guard !Task.isCancelled else {
            return
        }

        await runSearch()
    }

    private func runSearch() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let helpCenter, !term.isEmpty else {
            return
        }

        do {
            let page = try await store.help(.search(helpCenterID: helpCenter.id, query: term))

            guard term == query.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }

            searchError = nil
            results = page.data
        } catch {
            guard !Task.isCancelled, !error.isCancelled else {
                return
            }

            searchError = error
            results = nil
        }
    }
}

struct ArticleRow: View {
    let article: HelpArticleSummary
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            DisclosureRow {
                HStack(alignment: .top, spacing: 12) {
                    HelpRowIcon(systemName: "doc.text")

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
                }
                .padding(.vertical, 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CollectionRow: View {
    let collection: HelpCollection
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            DisclosureRow {
                HStack(alignment: .top, spacing: 12) {
                    HelpRowIcon(systemName: "folder")

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
                }
                .padding(.vertical, 4)
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

    @State private var children: [HelpCollection]?
    @State private var articles: [HelpArticleSummary]?
    @State private var loadError: KaraDeskError?

    var body: some View {
        List {
            if let children, !children.isEmpty {
                Section(Strings.collectionsHeader) {
                    ForEach(children) { child in
                        CollectionRow(collection: child) {
                            router.push(.collection(helpCenterID: helpCenterID, collectionID: child.id, title: child.name))
                        }
                    }
                }
            }

            if let articles, !articles.isEmpty {
                Section(Strings.articlesHeader) {
                    ForEach(articles) { article in
                        ArticleRow(article: article) {
                            router.push(.article(helpCenterID: helpCenterID, articleID: article.id))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 8, for: .scrollContent)
        .overlay {
            if let loadError {
                ErrorStateView(error: loadError, title: Strings.helpLoadFailed) {
                    await load()
                }
            } else if articles == nil || children == nil {
                ProgressView()
            } else if articles?.isEmpty == true, children?.isEmpty == true {
                Text(Strings.noArticles).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .closeToolbar()
        .task {
            await load()
        }
    }

    private func load() async {
        loadError = nil

        do {
            async let loadedChildren = store.help(.collections(helpCenterID: helpCenterID))
            async let loadedArticles = store.help(.articles(helpCenterID: helpCenterID, collectionID: collectionID))

            let (collectionPage, articlePage) = try await (loadedChildren, loadedArticles)
            children = collectionPage.data.withTotals().filter { $0.parentId == collectionID }
            articles = articlePage.data
        } catch let error as KaraDeskError {
            if !error.isCancelled {
                loadError = error
            }
        } catch {
            loadError = .unexpectedResponse
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

struct HelpRowIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}
