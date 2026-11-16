import SwiftUI
import UIKit

struct ImageViewerItem: Identifiable, Equatable {
    let urls: [URL]
    let index: Int

    var id: String {
        "\(index)-\(urls.map(\.absoluteString).joined(separator: "|"))"
    }
}

struct ImageViewer: View {
    let urls: [URL]
    let onFailure: (URL) -> Void

    @State private var index: Int
    @State private var backdrop: Double = 1
    @State private var sharing: [Any]?
    @Environment(\.dismiss) private var dismiss

    init(item: ImageViewerItem, onFailure: @escaping (URL) -> Void) {
        urls = item.urls
        self.onFailure = onFailure
        _index = State(initialValue: min(max(item.index, 0), max(item.urls.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backdrop)
                .ignoresSafeArea()

            ImagePager(
                urls: urls,
                index: $index,
                backdrop: $backdrop,
                onDismiss: { dismiss() },
                onFailure: { url in
                    dismiss()
                    onFailure(url)
                }
            )
            .ignoresSafeArea()

            controls
                .opacity(backdrop < 1 ? 0 : 1)
        }
        .statusBarHidden()
        .presentationBackground(.clear)
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
            ActivityView(items: sharing ?? [])
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }

    private var controls: some View {
        VStack {
            HStack {
                ViewerButton(symbol: "xmark", label: Strings.close) {
                    dismiss()
                }

                Spacer()

                if urls.count > 1 {
                    Text(String(localized: "viewer.position", defaultValue: "\(index + 1) of \(urls.count)", bundle: .module))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.4), in: Capsule())
                }

                Spacer()

                ViewerButton(symbol: "square.and.arrow.up", label: Strings.share) {
                    share()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    private func share() {
        guard urls.indices.contains(index) else {
            return
        }

        let url = urls[index]
        if let image = ImageLoader.shared.cached(url, .full) ?? ImageLoader.shared.cached(url) {
            sharing = [image]
        } else {
            sharing = [url]
        }
    }
}

private struct ViewerButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.4), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ImagePager: UIViewControllerRepresentable {
    let urls: [URL]
    @Binding var index: Int
    @Binding var backdrop: Double
    let onDismiss: () -> Void
    let onFailure: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 16]
        )
        controller.view.backgroundColor = .clear
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator

        if let page = context.coordinator.page(at: index) {
            controller.setViewControllers([page], direction: .forward, animated: false)
        }

        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: ImagePager

        init(_ parent: ImagePager) {
            self.parent = parent
        }

        func page(at index: Int) -> ZoomableImageController? {
            guard parent.urls.indices.contains(index) else {
                return nil
            }

            let page = ZoomableImageController(url: parent.urls[index], index: index)
            page.onDrag = { [weak self] progress in
                self?.parent.backdrop = 1 - progress
            }
            page.onDismiss = { [weak self] in
                self?.parent.onDismiss()
            }
            page.onFailure = { [weak self] url in
                self?.parent.onFailure(url)
            }
            return page
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let current = viewController as? ZoomableImageController else {
                return nil
            }

            return page(at: current.index - 1)
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let current = viewController as? ZoomableImageController else {
                return nil
            }

            return page(at: current.index + 1)
        }

        func pageViewController(_ controller: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let current = controller.viewControllers?.first as? ZoomableImageController else {
                return
            }

            parent.index = current.index
        }
    }
}

final class ZoomableImageController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let url: URL
    let index: Int
    var onDrag: ((Double) -> Void)?
    var onDismiss: (() -> Void)?
    var onFailure: ((URL) -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var loadTask: Task<Void, Never>?

    init(url: URL, index: Int) {
        self.url = url
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.accessibilityIgnoresInvertColors = true
        scrollView.addSubview(imageView)

        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)

        load()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if scrollView.zoomScale == scrollView.minimumZoomScale {
            layoutImage()
        }
    }

    private func load() {
        if let image = ImageLoader.shared.cached(url, .full) {
            show(image)
            return
        }

        if let thumbnail = ImageLoader.shared.cached(url) {
            show(thumbnail)
        } else {
            spinner.startAnimating()
        }

        loadTask = Task { [weak self, url] in
            let image = await ImageLoader.shared.image(for: url, .full)

            guard let self, !Task.isCancelled else {
                return
            }

            spinner.stopAnimating()

            if let image {
                show(image)
            } else if imageView.image == nil {
                onFailure?(url)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }

    private func show(_ image: UIImage) {
        imageView.image = image
        imageView.accessibilityLabel = url.lastPathComponent

        if scrollView.zoomScale <= scrollView.minimumZoomScale {
            layoutImage()
        }
    }

    private func layoutImage() {
        guard let image = imageView.image, view.bounds.width > 0 else {
            return
        }

        let fitted = MediaLayout.fit(image.size, in: view.bounds.size)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        scrollView.contentSize = fitted
        centerImage()
    }

    private func centerImage() {
        let bounds = scrollView.bounds.size
        let content = imageView.frame.size
        scrollView.contentInset = UIEdgeInsets(
            top: max(0, (bounds.height - content.height) / 2),
            left: max(0, (bounds.width - content.width) / 2),
            bottom: 0,
            right: 0
        )
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        guard imageView.image != nil else {
            return
        }

        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }

        let point = gesture.location(in: imageView)
        let scale = min(scrollView.maximumZoomScale, 2.5)
        let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
        scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let progress = min(1, max(0, translation.y / 400))

        switch gesture.state {
        case .changed:
            scrollView.transform = CGAffineTransform(translationX: translation.x * 0.3, y: max(0, translation.y))
            onDrag?(progress)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).y

            if gesture.state == .ended, translation.y > 120 || velocity > 900 {
                onDismiss?()
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                    self.scrollView.transform = .identity
                }
                onDrag?(0)
            }
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }

        let velocity = pan.velocity(in: view)
        return scrollView.zoomScale <= scrollView.minimumZoomScale && velocity.y > 0 && velocity.y > abs(velocity.x)
    }
}

enum MediaLayout {
    static let maxWidth: CGFloat = 260
    static let maxImageHeight: CGFloat = 384
    static let gridSpacing: CGFloat = 6
    static let videoHeight: CGFloat = 146
    static let placeholder = CGSize(width: 260, height: 195)

    static func fit(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }

        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    static func singleImage(_ natural: CGSize?, maxWidth: CGFloat = maxWidth, maxHeight: CGFloat = maxImageHeight) -> CGSize {
        guard let natural, natural.width > 0, natural.height > 0 else {
            return CGSize(width: maxWidth, height: (maxWidth * placeholder.height / placeholder.width).rounded())
        }

        let scale = min(1, maxWidth / natural.width, maxHeight / natural.height)
        return CGSize(
            width: max(1, (natural.width * scale).rounded()),
            height: max(1, (natural.height * scale).rounded())
        )
    }

    static func gridTile(width: CGFloat = maxWidth, columns: Int = 2, spacing: CGFloat = gridSpacing) -> CGFloat {
        guard columns > 0 else {
            return width
        }

        return ((width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
    }
}
