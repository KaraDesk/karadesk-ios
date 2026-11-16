import Foundation
import Observation

@MainActor
@Observable
final class MessengerStore {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case failed(KaraDeskError)
    }

    struct Typing: Equatable {
        var author: Message.Author
        var until: Date
    }

    let spaceID: String
    let appID: String

    private(set) var phase: Phase = .idle
    private(set) var boot: BootResponse?
    private(set) var conversations: [Conversation] = []
    private(set) var threads: [Int: [Message]] = [:]
    private(set) var typing: [Int: Typing] = [:]
    private(set) var user: KaraDesk.User?
    private(set) var conversationsError: KaraDeskError?

    @ObservationIgnored var visibleConversationID: Int?
    @ObservationIgnored var isMessengerVisible = false
    @ObservationIgnored var onIncomingMessage: ((Message) -> Void)?
    @ObservationIgnored var onUnreadWaiting: ((Conversation, Conversation.Preview) -> Void)?
    @ObservationIgnored var onUnreadCountChange: ((Int) -> Void)?

    @ObservationIgnored private let client: APIClient
    @ObservationIgnored private let identity: IdentityStore
    @ObservationIgnored private let deviceProvider: @MainActor () -> BootRequest.Device
    @ObservationIgnored private var bootTask: Task<BootResponse, any Error>?
    @ObservationIgnored private var pushToken: String?
    @ObservationIgnored private var pushRegisteredSession: String?
    @ObservationIgnored private var pushUnregister: Task<Void, Never>?
    @ObservationIgnored private var realtime: RealtimeConnection?
    @ObservationIgnored private var realtimeTask: Task<Void, Never>?
    @ObservationIgnored private var lastUnreadCount = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var realtimeRejections = 0

    init(
        spaceID: String,
        appID: String,
        client: APIClient,
        identity: IdentityStore,
        device: @escaping @MainActor () -> BootRequest.Device
    ) {
        self.spaceID = spaceID
        self.appID = appID
        self.client = client
        self.identity = identity
        self.deviceProvider = device
        self.user = identity.user()
    }

    var unreadConversationCount: Int {
        conversations.filter { $0.unread && $0.mergedIntoId == nil }.count
    }

    var settings: MessengerSettings? {
        boot?.settings
    }

    var isIdentified: Bool {
        boot?.identity.type == .user
    }

    var rules: MessengerSettings.Rules {
        settings?.rules(identified: isIdentified) ?? .standard
    }

    func conversation(_ id: Int) -> Conversation? {
        conversations.first { $0.id == id }
    }

    // MARK: Identity

    func login(_ user: KaraDesk.User) async throws(KaraDeskError) {
        identity.setUser(user)
        self.user = user
        reset()
        try await start()
    }

    func update(_ changes: KaraDesk.User) async throws(KaraDeskError) {
        guard let current = user else {
            throw .notLoggedIn
        }

        let merged = current.merging(changes)

        guard merged != current else {
            return
        }

        identity.setUser(merged)
        user = merged
        boot = nil
        try await session()
    }

    func logout() {
        unregisterPushToken()
        identity.setUser(nil)
        identity.rotateVisitorID()
        user = nil
        reset()
    }

    // MARK: Session

    func start() async throws(KaraDeskError) {
        _ = try await session()
        await refreshConversations()
        announceWaitingReply()
    }

    func refreshAndAnnounce() async {
        guard phase == .ready else {
            return
        }

        await refreshConversations()
        announceWaitingReply()
    }

    private func announceWaitingReply() {
        guard !isMessengerVisible else {
            return
        }

        let waiting = conversations
            .filter { $0.unread && $0.mergedIntoId == nil }
            .compactMap { conversation in conversation.lastMessage.map { (conversation, $0) } }
            .filter { $0.1.authorType != .contact }
            .max { $0.1.createdAt < $1.1.createdAt }

        guard let (conversation, preview) = waiting else {
            return
        }

        guard UserDefaults.standard.string(forKey: announcedKey) != preview.id else {
            return
        }

        markAnnounced(preview.id)
        onUnreadWaiting?(conversation, preview)
    }

    private var announcedKey: String {
        "karadesk.announced.\(spaceID).\(appID)"
    }

    func markAnnounced(_ messageID: String) {
        UserDefaults.standard.set(messageID, forKey: announcedKey)
    }

    @discardableResult
    func session() async throws(KaraDeskError) -> BootResponse {
        if let boot, boot.expiresAt.timeIntervalSinceNow > 60 {
            return boot
        }

        if let bootTask {
            return try await Self.value(of: bootTask)
        }

        let generation = generation
        let device = deviceProvider()
        let task = Task { [client, identity, user, spaceID, appID] () async throws -> BootResponse in
            let request = BootRequest(
                spaceId: spaceID,
                appId: appID,
                visitorId: identity.visitorID(),
                userId: user?.id,
                email: user?.email,
                name: user?.name,
                phone: user?.phone,
                avatar: user?.avatarURL?.absoluteString,
                signedUpAt: user?.signedUpAt.map { Int($0.timeIntervalSince1970) },
                userHash: user?.userHash,
                device: device
            )

            return try await client.send(.boot(request), token: nil)
        }

        bootTask = task

        if phase != .ready {
            phase = .loading
        }

        do {
            let response = try await Self.value(of: task)

            guard generation == self.generation else {
                return response
            }

            bootTask = nil
            boot = response
            phase = .ready
            connectRealtime(token: response.token)
            Log.session.debug("Messenger session started")
            Task { await registerPushToken() }
            return response
        } catch {
            if generation == self.generation {
                bootTask = nil
                phase = .failed(error)
            }

            if case let .unavailable(message) = error {
                Log.session.error("The messenger is unavailable: \(message, privacy: .public)")
            } else if case let .identityVerificationFailed(message) = error {
                Log.session.error("Identity verification failed: \(message, privacy: .public)")
            }

            throw error
        }
    }

    func refreshConversations() async {
        do {
            let page = try await authorized(.conversations())
            conversationsError = nil
            conversations = page.data.sorted { $0.sortDate > $1.sortDate }
            publishUnreadCount()
        } catch where !error.isCancelled {
            conversationsError = error
        } catch {
            return
        }
    }

    func reconnected() async {
        switch phase {
        case .failed:
            try? await start()
        case .ready:
            await resumeRealtime()
            await refreshConversations()
        case .idle, .loading:
            break
        }
    }

    // MARK: Conversations

    func loadThread(_ conversationID: Int) async throws(KaraDeskError) {
        let thread = try await authorized(.conversation(conversationID))
        threads[conversationID] = thread.messages
        upsert(thread.conversation)
    }

    @discardableResult
    func send(_ body: String, attachments: [UploadedFile], to conversationID: Int?) async throws(KaraDeskError) -> Int {
        let message = OutgoingMessage(
            body: body,
            attachments: attachments.isEmpty ? nil : attachments.map { .init(assetId: $0.id) }
        )

        guard let conversationID else {
            let hadContact = boot?.contact != nil
            let thread = try await authorized(.startConversation(message))
            threads[thread.conversation.id] = thread.messages
            upsert(thread.conversation)

            if !hadContact {
                await reconnectRealtime()
            }

            return thread.conversation.id
        }

        let sent = try await authorized(.send(message, to: conversationID))
        append(sent)
        return sent.conversationId
    }

    func markRead(_ conversationID: Int, force: Bool = false) async {
        guard force || conversation(conversationID)?.unread == true,
              let updated = try? await authorized(.markRead(conversationID))
        else {
            return
        }

        upsert(updated)
    }

    func rate(_ message: Message, rating: Int?, remark: String?) async throws(KaraDeskError) {
        let updated = try await authorized(.rate(
            RatingInput(messageId: message.id, rating: rating, remark: remark),
            conversationID: message.conversationId
        ))
        replace(updated)
    }

    func upload(_ data: Data, filename: String, contentType: String) async throws(KaraDeskError) -> UploadedFile {
        let ticket = try await authorized(.startUpload(UploadRequest(filename: filename, contentType: contentType, byteSize: data.count)))
        try await client.upload(data, named: filename, contentType: contentType, to: ticket.upload)
        return try await authorized(.completeUpload(ticket.asset.id))
    }

    func react(_ reaction: ArticleReaction, articleID: Int) async {
        _ = try? await authorized(.react(reaction, articleID: articleID))
    }

    func sendTyping(_ conversationID: Int) {
        guard let realtime else {
            return
        }

        Task {
            await realtime.sendTyping(conversationID: conversationID)
        }
    }

    // MARK: Help center

    func help<Response>(_ request: APIRequest<Response>) async throws(KaraDeskError) -> Response {
        try await client.send(request, token: nil)
    }

    // MARK: Requests

    func authorized<Response>(_ request: APIRequest<Response>) async throws(KaraDeskError) -> Response {
        let token = try await session().token

        do {
            return try await client.send(request, token: token)
        } catch let error where error.isExpiredSession {
            boot = nil
            let fresh = try await session().token
            return try await client.send(request, token: fresh)
        } catch let error where error.isMessengerUnavailable {
            Log.session.error("The messenger became unavailable: \(error.localizedDescription, privacy: .public)")
            suspendRealtime()
            phase = .failed(error)
            throw error
        }
    }

    // MARK: Push

    func setPushToken(_ token: String) {
        guard token != pushToken else {
            return
        }

        pushToken = token
        pushRegisteredSession = nil

        Task { await registerPushToken() }
    }

    func registerPushToken() async {
        await pushUnregister?.value

        guard let pushToken, let session = boot?.token, phase == .ready, pushRegisteredSession != session else {
            return
        }

        pushRegisteredSession = session

        do {
            _ = try await client.send(
                .registerPushToken(PushTokenInput(token: pushToken, environment: PushEnvironment.current.rawValue)),
                token: session
            )
            Log.session.debug("Registered for push notifications")
        } catch {
            if pushRegisteredSession == session {
                pushRegisteredSession = nil
            }
            Log.session.error("Couldn't register for push notifications: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func unregisterPushToken() {
        guard let pushToken, let session = boot?.token else {
            return
        }

        pushRegisteredSession = nil

        let client = client
        let previous = pushUnregister

        pushUnregister = Task {
            await previous?.value
            _ = try? await client.send(.removePushToken(pushToken), token: session)
        }
    }

    // MARK: Realtime

    func suspendRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let realtime {
            Task { await realtime.stop() }
        }

        realtime = nil
    }

    func resumeRealtime() async {
        guard phase == .ready, realtime == nil, let response = try? await session(), realtime == nil else {
            return
        }

        connectRealtime(token: response.token)
    }

    private func connectRealtime(token: String) {
        realtimeTask?.cancel()

        let previous = realtime
        let connection = RealtimeConnection(baseURL: client.baseURL, token: token, session: client.session)
        realtime = connection

        realtimeTask = Task { [weak self] in
            await previous?.stop()
            await connection.start()

            for await event in connection.events {
                self?.apply(event)
            }
        }
    }

    private func reconnectRealtime() async {
        guard let token = boot?.token else {
            return
        }

        connectRealtime(token: token)
    }

    func apply(_ event: RealtimeEvent) {
        switch event {
        case .ready:
            realtimeRejections = 0
            Task { await refreshConversations() }
        case let .messageCreated(message):
            append(message)
        case let .messageUpdated(message):
            replace(message)
        case let .messageDeleted(conversationID, messageID):
            threads[conversationID]?.removeAll { $0.id == messageID }
        case let .conversationChanged(conversation):
            upsert(conversation)
        case let .typing(conversationID, author):
            typing[conversationID] = Typing(author: author, until: .now.addingTimeInterval(6))
        case .unauthorized:
            realtimeRejections += 1
            let delay = min(60, 5 * (1 << min(realtimeRejections - 1, 4)))
            let generation = generation

            Task {
                try? await Task.sleep(for: .seconds(delay))

                guard generation == self.generation else {
                    return
                }

                boot = nil
                _ = try? await session()
            }
        }
    }

    // MARK: State

    private func append(_ message: Message) {
        let id = message.conversationId
        var thread = threads[id] ?? []

        if let index = thread.firstIndex(where: { $0.id == message.id }) {
            thread[index] = message
        } else {
            thread.append(message)
            thread.sort { $0.createdAt < $1.createdAt }
        }

        if threads[id] != nil {
            threads[id] = thread
        }

        if !message.isFromContact {
            typing[id] = nil
        }

        guard var conversation = conversation(id) else {
            Task { await refreshConversations() }
            return
        }

        conversation.lastMessageAt = message.createdAt

        if message.kind != .other("note") {
            conversation.lastMessage = Conversation.Preview(message)
        }

        if !message.isFromContact && message.kind != .other("note") {
            if visibleConversationID == id {
                Task { await markRead(id, force: true) }
            } else {
                conversation.unread = true
                conversation.unreadCount += 1

                if !isMessengerVisible {
                    markAnnounced(message.id)
                    onIncomingMessage?(message)
                }
            }
        }

        upsert(conversation)
    }

    private func replace(_ message: Message) {
        guard let index = threads[message.conversationId]?.firstIndex(where: { $0.id == message.id }) else {
            return
        }

        threads[message.conversationId]?[index] = message
    }

    private func upsert(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }

        conversations.sort { $0.sortDate > $1.sortDate }
        publishUnreadCount()
    }

    private func publishUnreadCount() {
        let count = unreadConversationCount

        guard count != lastUnreadCount else {
            return
        }

        lastUnreadCount = count
        onUnreadCountChange?(count)
    }

    private func reset() {
        generation += 1
        bootTask?.cancel()
        bootTask = nil
        realtimeTask?.cancel()
        realtimeTask = nil

        if let realtime {
            Task { await realtime.stop() }
        }

        realtime = nil
        boot = nil
        conversations = []
        conversationsError = nil
        threads = [:]
        typing = [:]
        phase = .idle
        publishUnreadCount()
    }

    private static func value(of task: Task<BootResponse, any Error>) async throws(KaraDeskError) -> BootResponse {
        do {
            return try await task.value
        } catch let error as KaraDeskError {
            throw error
        } catch is CancellationError {
            throw .network(.cancelled)
        } catch {
            throw .unexpectedResponse
        }
    }
}

extension KaraDeskError {
    var isMessengerUnavailable: Bool {
        if case let .unavailable(message) = self {
            return message.localizedCaseInsensitiveContains("messenger")
        }

        return false
    }

    var isExpiredSession: Bool {
        if case .server(401, _) = self {
            return true
        }

        return false
    }
}
