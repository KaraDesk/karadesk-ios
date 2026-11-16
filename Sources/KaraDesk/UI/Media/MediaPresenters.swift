import AVKit
import Combine
import QuickLook
import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") == nil {
            controller.excludedActivityTypes = [.saveToCameraRoll]
        }

        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    let onFailure: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        controller.entersFullScreenWhenPlaybackBegins = false

        context.coordinator.status = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [url, onFailure] status in
                if status == .failed {
                    onFailure(url)
                }
            }

        player.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause()
        coordinator.status = nil
    }

    final class Coordinator {
        var status: AnyCancellable?
    }
}

struct VideoPlayerScreen: View {
    let url: URL
    let onFailure: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VideoPlayerView(url: url) { failed in
            dismiss()
            onFailure(failed)
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.close)
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
}

struct QuickLookPresenter: UIViewControllerRepresentable {
    @Binding var url: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.isHidden = true
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.onDismiss = {
            url = nil
        }

        guard let url, coordinator.presented != url, controller.presentedViewController == nil else {
            return
        }

        coordinator.presented = url
        coordinator.item = url as NSURL

        let preview = QLPreviewController()
        preview.dataSource = coordinator
        preview.delegate = coordinator

        DispatchQueue.main.async {
            controller.present(preview, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, QLPreviewControllerDataSource, @preconcurrency QLPreviewControllerDelegate {
        var item: NSURL?
        var presented: URL?
        var onDismiss: (() -> Void)?

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            item == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            item ?? NSURL()
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            presented = nil
            item = nil
            onDismiss?()
        }
    }
}
