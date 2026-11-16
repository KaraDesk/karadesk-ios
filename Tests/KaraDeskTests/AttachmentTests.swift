import CoreGraphics
import UIKit
import Foundation
import Testing
@testable import KaraDesk

@Suite("Attachments")
struct AttachmentTests {
    func file(_ contentType: String, name: String = "a", assetID: String = "as_1") -> MessageAttachment.File {
        MessageAttachment.File(
            assetID: assetID,
            name: name,
            contentType: contentType,
            byteSize: 10,
            url: URL(string: "https://cdn.example.com/\(assetID)")!
        )
    }

    @Test func classifiesLikeTheWebWidget() {
        #expect(file("image/png").kind == .image)
        #expect(file("image/jpeg").kind == .image)
        #expect(file("image/gif").kind == .image)
        #expect(file("image/webp").kind == .image)
        #expect(file("IMAGE/PNG").kind == .image)
        #expect(file("image/heic").kind == .file)
        #expect(file("image/svg+xml").kind == .file)
        #expect(file("video/mp4").kind == .video)
        #expect(file("video/quicktime").kind == .video)
        #expect(file("application/pdf").kind == .file)
        #expect(file("application/octet-stream").kind == .file)
    }

    @Test func sizesFormatLikeTheWebWidget() {
        #expect(Formatting.byteCount(0) == "")
        #expect(Formatting.byteCount(512) == "512 B")
        #expect(Formatting.byteCount(1023) == "1023 B")
        #expect(Formatting.byteCount(1024) == "1 KB")
        #expect(Formatting.byteCount(1536) == "2 KB")
        #expect(Formatting.byteCount(1024 * 1024) == "1 MB")
        #expect(Formatting.byteCount(1_572_864) == "1.5 MB")
        #expect(Formatting.byteCount(26_214_400) == "25 MB")
    }

    @Test func durationsFormatAsClockTime() {
        #expect(Formatting.duration(0) == nil)
        #expect(Formatting.duration(.nan) == nil)
        #expect(Formatting.duration(5.4) == "0:05")
        #expect(Formatting.duration(75) == "1:15")
        #expect(Formatting.duration(3725) == "1:02:05")
    }

    @Test func singleImagesFitWithoutUpscaling() {
        #expect(MediaLayout.singleImage(CGSize(width: 1200, height: 800)) == CGSize(width: 260, height: 173))
        #expect(MediaLayout.singleImage(CGSize(width: 1000, height: 4000)) == CGSize(width: 96, height: 384))
        #expect(MediaLayout.singleImage(CGSize(width: 100, height: 50)) == CGSize(width: 100, height: 50))
        #expect(MediaLayout.singleImage(nil) == CGSize(width: 260, height: 195))
        #expect(MediaLayout.singleImage(CGSize(width: 0, height: 10)) == CGSize(width: 260, height: 195))
    }

    @Test func gridTilesSplitTheWidth() {
        #expect(MediaLayout.gridTile() == 127)
        #expect(MediaLayout.gridTile(width: 300, columns: 3, spacing: 6) == 96)
        #expect(MediaLayout.gridTile(width: 100, columns: 0) == 100)
    }

    @Test func viewerFitsImagesToTheScreen() {
        #expect(MediaLayout.fit(CGSize(width: 2000, height: 1000), in: CGSize(width: 400, height: 800)) == CGSize(width: 400, height: 200))
        #expect(MediaLayout.fit(CGSize(width: 100, height: 400), in: CGSize(width: 400, height: 800)) == CGSize(width: 200, height: 800))
        #expect(MediaLayout.fit(.zero, in: CGSize(width: 400, height: 800)) == .zero)
    }

    @Test func downloadsLandInTheCachesDirectory() {
        let root = URL(fileURLWithPath: "/tmp/cache", isDirectory: true)
        let destination = AttachmentDownloads.destination(for: file("application/pdf", name: "../Q3: report?.pdf", assetID: "as/9"), root: root)

        #expect(destination.path == "/tmp/cache/as-9/Q3- report-.pdf")
        #expect(AttachmentDownloads.sanitized("...") == "file")
        #expect(AttachmentDownloads.sanitized(" notes.txt ") == "notes.txt")
        #expect(AttachmentDownloads.directory.path.contains("/Caches/KaraDesk/Attachments"))
    }

    @Test func thumbnailsAreDownsampled() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = try #require(UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000))
        }.pngData())

        let thumbnail = try #require(await ImageLoader.decode(data, maxPixels: 1024))
        let full = try #require(await ImageLoader.decode(data, maxPixels: nil))

        #expect(thumbnail.size == CGSize(width: 1024, height: 341))
        #expect(full.size == CGSize(width: 3000, height: 1000))
        #expect(await ImageLoader.decode(Data("nope".utf8), maxPixels: 1024) == nil)
    }
}
