import SafariServices
import SwiftUI

struct AttachmentView: View {
    let attachment: MessageAttachment
    let onOpenArticle: (MessageAttachment.Article) -> Void

    @State private var previewURL: URL?

    var body: some View {
        content
            .sheet(item: $previewURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch attachment {
        case let .file(file) where file.isImage:
            Button {
                previewURL = file.url
            } label: {
                AsyncImage(url: file.url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color(uiColor: .secondarySystemBackground)
                            .frame(width: 220, height: 160)
                            .overlay(ProgressView())
                    }
                }
                .frame(maxWidth: 240, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(file.name)
        case let .file(file):
            Button {
                previewURL = file.url
            } label: {
                AttachmentCard(symbol: "doc", title: file.name, detail: Formatting.byteCount(file.byteSize), trailing: "arrow.down.circle")
            }
            .buttonStyle(.plain)
        case let .article(article):
            Button {
                onOpenArticle(article)
            } label: {
                AttachmentCard(symbol: "book", title: article.title, detail: article.description, trailing: "chevron.right")
            }
            .buttonStyle(.plain)
        case let .link(url, title):
            Button {
                previewURL = url
            } label: {
                AttachmentCard(symbol: "link", title: title ?? url.host() ?? url.absoluteString, detail: url.host(), trailing: "arrow.up.right")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AttachmentCard: View {
    let symbol: String
    let title: String
    let detail: String?
    let trailing: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: trailing)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(width: 260)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
        .accessibilityElement(children: .combine)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String {
        absoluteString
    }
}
