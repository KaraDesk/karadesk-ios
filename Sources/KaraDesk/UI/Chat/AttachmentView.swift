import QuickLook
import SafariServices
import SwiftUI

struct MessageAttachmentsView: View {
    let attachments: [MessageAttachment]
    let mine: Bool
    let onOpenArticle: (MessageAttachment.Article) -> Void

    @State private var viewer: ImageViewerItem?
    @State private var video: URL?
    @State private var quickLook: URL?
    @State private var browserURL: URL?
    @State private var pendingFallback: URL?

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
            if !images.isEmpty {
                imageBlock
            }

            ForEach(Array(others.enumerated()), id: \.offset) { _, attachment in
                row(for: attachment)
            }
        }
        .fullScreenCover(item: $viewer, onDismiss: presentPendingFallback) { item in
            ImageViewer(item: item) { url in
                pendingFallback = url
            }
        }
        .fullScreenCover(item: $video, onDismiss: presentPendingFallback) { url in
            VideoPlayerScreen(url: url) { failed in
                pendingFallback = failed
            }
        }
        .sheet(item: $browserURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        .background {
            QuickLookPresenter(url: $quickLook)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    private var images: [MessageAttachment.File] {
        attachments.compactMap { attachment in
            if case let .file(file) = attachment, file.kind == .image {
                return file
            }

            return nil
        }
    }

    private var others: [MessageAttachment] {
        attachments.filter { attachment in
            if case let .file(file) = attachment, file.kind == .image {
                return false
            }

            return true
        }
    }

    @ViewBuilder
    private var imageBlock: some View {
        let urls = images.map(\.url)

        if images.count == 1, let image = images.first {
            Button {
                viewer = ImageViewerItem(urls: urls, index: 0)
            } label: {
                SingleImageView(url: image.url)
            }
            .buttonStyle(MediaButtonStyle())
            .accessibilityLabel(image.name)
        } else {
            let side = MediaLayout.gridTile()

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(side), spacing: MediaLayout.gridSpacing), count: 2),
                alignment: mine ? .trailing : .leading,
                spacing: MediaLayout.gridSpacing
            ) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Button {
                        viewer = ImageViewerItem(urls: urls, index: index)
                    } label: {
                        ImageTile(url: image.url, side: side)
                    }
                    .buttonStyle(MediaButtonStyle())
                    .accessibilityLabel(image.name)
                }
            }
            .frame(width: MediaLayout.maxWidth, alignment: mine ? .trailing : .leading)
        }
    }

    @ViewBuilder
    private func row(for attachment: MessageAttachment) -> some View {
        switch attachment {
        case let .file(file) where file.kind == .video:
            Button {
                video = file.url
            } label: {
                VideoTile(url: file.url)
            }
            .buttonStyle(MediaButtonStyle())
            .accessibilityLabel(file.name)
            .accessibilityHint(Strings.playVideo)
        case let .file(file):
            FileRow(file: file) {
                open(file)
            }
        case let .article(article):
            Button {
                onOpenArticle(article)
            } label: {
                AttachmentCard(symbol: "book", title: article.title, detail: article.description) {
                    TrailingSymbol(name: "chevron.right")
                }
            }
            .buttonStyle(.plain)
        case let .link(url, title):
            Button {
                browserURL = url
            } label: {
                AttachmentCard(symbol: "link", title: title ?? url.host() ?? url.absoluteString, detail: url.host()) {
                    TrailingSymbol(name: "arrow.up.right")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func open(_ file: MessageAttachment.File) {
        Task {
            guard let local = await AttachmentDownloads.shared.download(file) else {
                if AttachmentDownloads.shared.state(for: file) == .failed {
                    browserURL = file.url
                }

                return
            }

            if QLPreviewController.canPreview(local as NSURL) {
                quickLook = local
            } else {
                browserURL = file.url
            }
        }
    }

    private func presentPendingFallback() {
        guard let url = pendingFallback else {
            return
        }

        pendingFallback = nil
        browserURL = url
    }
}

private struct MediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SingleImageView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL) {
        self.url = url
        _image = State(initialValue: ImageLoader.shared.cached(url))
    }

    var body: some View {
        let size = MediaLayout.singleImage(ImageLoader.shared.knownSize(url) ?? image?.size)

        ZStack {
            Color(uiColor: .secondarySystemBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else if failed {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: image)
        .task(id: url) {
            guard image == nil else {
                return
            }

            image = await ImageLoader.shared.image(for: url)
            failed = image == nil
        }
    }
}

private struct ImageTile: View {
    let url: URL
    let side: CGFloat

    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL, side: CGFloat) {
        self.url = url
        self.side = side
        _image = State(initialValue: ImageLoader.shared.cached(url))
    }

    var body: some View {
        Color(uiColor: .secondarySystemBackground)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if failed {
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeOut(duration: 0.2), value: image)
            .task(id: url) {
                guard image == nil else {
                    return
                }

                image = await ImageLoader.shared.image(for: url)
                failed = image == nil
            }
    }
}

private struct VideoTile: View {
    let url: URL

    @State private var preview: VideoPreview?

    init(url: URL) {
        self.url = url
        _preview = State(initialValue: VideoPreviewLoader.shared.cached(url))
    }

    var body: some View {
        Color(uiColor: .secondarySystemBackground)
            .overlay {
                if let image = preview?.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration = preview?.duration.flatMap(Formatting.duration) {
                    Text(duration)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(8)
                }
            }
            .frame(width: MediaLayout.maxWidth, height: MediaLayout.videoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeOut(duration: 0.2), value: preview?.image)
            .task(id: url) {
                guard preview == nil else {
                    return
                }

                preview = await VideoPreviewLoader.shared.preview(for: url)
            }
    }
}

private struct FileRow: View {
    let file: MessageAttachment.File
    let open: () -> Void

    var body: some View {
        let state = AttachmentDownloads.shared.state(for: file)

        Button(action: open) {
            AttachmentCard(symbol: "doc.text", title: file.name, detail: Formatting.byteCount(file.byteSize)) {
                switch state {
                case let .downloading(fraction):
                    DownloadRing(fraction: fraction)
                case .ready:
                    TrailingSymbol(name: "doc.viewfinder")
                case .failed:
                    TrailingSymbol(name: "exclamationmark.arrow.circlepath")
                case nil:
                    TrailingSymbol(name: "arrow.down.circle")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(accessibilityValue(state))
    }

    private func accessibilityValue(_ state: AttachmentDownloads.State?) -> String {
        if case let .downloading(fraction) = state {
            return fraction.formatted(.percent.precision(.fractionLength(0)))
        }

        return ""
    }
}

private struct DownloadRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: max(0.04, fraction))
                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: fraction)
        }
        .frame(width: 18, height: 18)
    }
}

private struct TrailingSymbol: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

private struct AttachmentCard<Trailing: View>: View {
    let symbol: String
    let title: String
    let detail: String?
    @ViewBuilder let trailing: () -> Trailing

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
                    .truncationMode(.middle)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(10)
        .frame(width: MediaLayout.maxWidth)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
