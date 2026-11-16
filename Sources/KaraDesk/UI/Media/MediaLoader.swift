import AVFoundation
import ImageIO
import Observation
import UIKit

@MainActor
final class ImageLoader {
    enum Variant: Sendable {
        case thumbnail
        case full
    }

    static let shared = ImageLoader()
    static let thumbnailPixels: CGFloat = 1024

    private let thumbnails = NSCache<NSURL, UIImage>()
    private let originals = NSCache<NSURL, UIImage>()
    private var sizes: [URL: CGSize] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        thumbnails.totalCostLimit = 96 * 1024 * 1024
        originals.countLimit = 4
    }

    func cached(_ url: URL, _ variant: Variant = .thumbnail) -> UIImage? {
        cache(for: variant).object(forKey: url as NSURL)
    }

    func knownSize(_ url: URL) -> CGSize? {
        sizes[url]
    }

    func image(for url: URL, _ variant: Variant = .thumbnail) async -> UIImage? {
        if let image = cached(url, variant) {
            return image
        }

        let key = "\(variant)|\(url.absoluteString)"

        if let task = inFlight[key] {
            return await task.value
        }

        let maxPixels: CGFloat? = variant == .thumbnail ? Self.thumbnailPixels : nil
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse).map({ (200 ..< 300).contains($0.statusCode) }) ?? true
            else {
                return nil
            }

            return await Self.decode(data, maxPixels: maxPixels)
        }

        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil

        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache(for: variant).setObject(image, forKey: url as NSURL, cost: cost)

            if variant == .thumbnail {
                sizes[url] = image.size
            }
        }

        return image
    }

    private func cache(for variant: Variant) -> NSCache<NSURL, UIImage> {
        switch variant {
        case .thumbnail:
            return thumbnails
        case .full:
            return originals
        }
    }

    nonisolated static func decode(_ data: Data, maxPixels: CGFloat?) async -> UIImage? {
        guard let maxPixels else {
            guard let image = UIImage(data: data) else {
                return nil
            }

            return await image.byPreparingForDisplay() ?? image
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: thumbnail)
    }
}

struct VideoPreview: Sendable {
    var image: UIImage?
    var duration: Double?
}

@MainActor
final class VideoPreviewLoader {
    static let shared = VideoPreviewLoader()

    private var previews: [URL: VideoPreview] = [:]
    private var inFlight: [URL: Task<VideoPreview, Never>] = [:]

    func cached(_ url: URL) -> VideoPreview? {
        previews[url]
    }

    func preview(for url: URL) async -> VideoPreview {
        if let preview = previews[url] {
            return preview
        }

        if let task = inFlight[url] {
            return await task.value
        }

        let task = Task.detached(priority: .utility) {
            await Self.load(url)
        }

        inFlight[url] = task
        let preview = await task.value
        inFlight[url] = nil
        previews[url] = preview
        return preview
    }

    nonisolated private static func load(_ url: URL) async -> VideoPreview {
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 720)
        let frame = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)).image

        return VideoPreview(
            image: frame.map { UIImage(cgImage: $0) },
            duration: duration.map(\.seconds)
        )
    }
}

@MainActor
@Observable
final class AttachmentDownloads {
    enum State: Equatable {
        case downloading(Double)
        case ready(URL)
        case failed
    }

    static let shared = AttachmentDownloads()

    private(set) var states: [String: State] = [:]

    @ObservationIgnored private var observations: [String: NSKeyValueObservation] = [:]

    func state(for file: MessageAttachment.File) -> State? {
        if let state = states[file.assetID] {
            return state
        }

        let destination = Self.destination(for: file)

        if FileManager.default.fileExists(atPath: destination.path) {
            return .ready(destination)
        }

        return nil
    }

    func download(_ file: MessageAttachment.File) async -> URL? {
        if case let .ready(url) = state(for: file) {
            return url
        }

        if case .downloading = states[file.assetID] {
            return nil
        }

        states[file.assetID] = .downloading(0)
        let destination = Self.destination(for: file)
        let assetID = file.assetID

        let result: URL? = await withCheckedContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: file.url) { location, response, _ in
                guard let location,
                      (response as? HTTPURLResponse).map({ (200 ..< 300).contains($0.statusCode) }) ?? true
                else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let manager = FileManager.default
                    try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

                    if manager.fileExists(atPath: destination.path) {
                        try manager.removeItem(at: destination)
                    }

                    try manager.moveItem(at: location, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(returning: nil)
                }
            }

            observations[assetID] = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                let fraction = progress.fractionCompleted

                Task { @MainActor in
                    if case .downloading = self?.states[assetID] {
                        self?.states[assetID] = .downloading(fraction)
                    }
                }
            }

            task.resume()
        }

        observations[assetID] = nil
        states[assetID] = result.map { .ready($0) } ?? .failed
        return result
    }

    nonisolated static func destination(for file: MessageAttachment.File, root: URL = directory) -> URL {
        root
            .appending(path: sanitized(file.assetID), directoryHint: .isDirectory)
            .appending(path: sanitized(file.name), directoryHint: .notDirectory)
    }

    nonisolated static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters).union(.newlines)
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".- ").union(.whitespaces))

        return cleaned.isEmpty ? "file" : String(cleaned.prefix(120))
    }

    nonisolated static var directory: URL {
        URL.cachesDirectory.appending(path: "KaraDesk/Attachments", directoryHint: .isDirectory)
    }
}
