import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class ChatModel {
    struct PendingAttachment: Identifiable {
        enum Status: Equatable {
            case uploading
            case ready(UploadedFile)
            case failed
        }

        let id = UUID()
        let name: String
        let contentType: String
        let byteSize: Int
        let preview: UIImage?
        let data: Data
        var status: Status = .uploading
    }

    static let maximumAttachments = 10

    private(set) var conversationID: Int?
    var draft: String
    private(set) var attachments: [PendingAttachment] = []
    private(set) var isSending = false
    private(set) var isLoading = false
    private(set) var loadError: KaraDeskError?
    var notice: String?

    @ObservationIgnored private let store: MessengerStore
    @ObservationIgnored private var lastTypingSent = Date.distantPast

    init(store: MessengerStore, conversationID: Int?, draft: String?) {
        self.store = store
        self.conversationID = conversationID
        self.draft = draft ?? ""
    }

    var messages: [Message] {
        conversationID.flatMap { store.threads[$0] } ?? []
    }

    var conversation: Conversation? {
        conversationID.flatMap(store.conversation)
    }

    var isUploading: Bool {
        attachments.contains { $0.status == .uploading }
    }

    var canSend: Bool {
        !isSending && !isUploading && (!trimmedDraft.isEmpty || !readyFiles.isEmpty)
    }

    var attachmentRules: MessengerSettings.AttachmentRules {
        store.settings?.attachments ?? .disabled
    }

    var isLocked: Bool {
        guard let conversation,
              conversation.state == .closed,
              let days = store.rules.closedReplyDays,
              let closedAt = conversation.closedAt
        else {
            return false
        }

        return Date.now.timeIntervalSince(closedAt) >= Double(days) * 86_400
    }

    var typingAuthor: Message.Author? {
        guard let conversationID, let typing = store.typing[conversationID], typing.until > .now else {
            return nil
        }

        return typing.author
    }

    func load() async {
        guard let conversationID else {
            return
        }

        store.visibleConversationID = conversationID

        if store.threads[conversationID] == nil {
            await loadThread()
        }

        await store.markRead(conversationID)
    }

    func loadThread() async {
        guard let conversationID else {
            return
        }

        isLoading = true
        loadError = nil

        defer {
            isLoading = false
        }

        do {
            try await store.loadThread(conversationID)
        } catch where !error.isCancelled {
            loadError = error
        } catch {
            return
        }
    }

    func disappear() {
        if store.visibleConversationID == conversationID {
            store.visibleConversationID = nil
        }
    }

    func draftChanged() {
        guard let conversationID, !trimmedDraft.isEmpty, Date.now.timeIntervalSince(lastTypingSent) > 3 else {
            return
        }

        lastTypingSent = .now
        store.sendTyping(conversationID)
    }

    func send() async -> Int? {
        guard canSend else {
            return nil
        }

        isSending = true
        notice = nil

        defer {
            isSending = false
        }

        do {
            let id = try await store.send(trimmedDraft, attachments: readyFiles, to: conversationID)
            draft = ""
            attachments = []

            if conversationID != id {
                conversationID = id
                store.visibleConversationID = id
            }

            return id
        } catch {
            notice = "\(Strings.notSent) \(error.userMessage)"
            return nil
        }
    }

    func rate(_ message: Message, rating: Int?, remark: String?) async {
        do {
            try await store.rate(message, rating: rating, remark: remark)
        } catch {
            notice = error.userMessage
        }
    }

    func interact(with message: Message, _ interaction: ComponentInteraction) async -> String? {
        do {
            try await store.interact(with: message, interaction)
            return nil
        } catch {
            return error.userMessage
        }
    }

    func openLink(in message: Message, _ interaction: ComponentInteraction) {
        Task {
            try? await store.interact(with: message, interaction)
        }
    }

    // MARK: Attachments

    func addFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            notice = Strings.uploadFailed
            return
        }

        let type = UTType(filenameExtension: url.pathExtension)
        add(data, name: url.lastPathComponent, contentType: type?.preferredMIMEType ?? "application/octet-stream")
    }

    func addImage(_ data: Data, contentType: UTType?) {
        if contentType == .gif, attachmentRules.accept.contains("image/gif") {
            add(data, name: "Image.gif", contentType: "image/gif")
            return
        }

        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) else {
            notice = Strings.fileTypeNotAllowed
            return
        }

        add(jpeg, name: "Photo.jpg", contentType: "image/jpeg", preview: image)
    }

    func remove(_ attachment: PendingAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    func retry(_ attachment: PendingAttachment) {
        guard let index = attachments.firstIndex(where: { $0.id == attachment.id }) else {
            return
        }

        attachments[index].status = .uploading
        notice = nil
        upload(attachments[index])
    }

    private func add(_ data: Data, name: String, contentType: String, preview: UIImage? = nil) {
        let rules = attachmentRules

        guard attachments.count < Self.maximumAttachments else {
            return
        }

        guard rules.accept.isEmpty || rules.accept.contains(contentType) else {
            notice = Strings.fileTypeNotAllowed
            return
        }

        guard rules.maxBytes == 0 || data.count <= rules.maxBytes else {
            notice = Strings.fileTooLarge
            return
        }

        let pending = PendingAttachment(
            name: name,
            contentType: contentType,
            byteSize: data.count,
            preview: preview ?? (contentType.hasPrefix("image/") ? UIImage(data: data) : nil),
            data: data
        )
        attachments.append(pending)
        notice = nil
        upload(pending)
    }

    private func upload(_ pending: PendingAttachment) {
        Task {
            let status: PendingAttachment.Status

            do {
                status = .ready(try await store.upload(pending.data, filename: pending.name, contentType: pending.contentType))
            } catch {
                status = .failed
                notice = (error as? KaraDeskError)?.userMessage ?? Strings.uploadFailed
            }

            if let index = attachments.firstIndex(where: { $0.id == pending.id }) {
                attachments[index].status = status
            }
        }
    }

    private var readyFiles: [UploadedFile] {
        attachments.compactMap {
            if case let .ready(file) = $0.status {
                return file
            }

            return nil
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
