import Foundation
import UIKit

struct QueuedEvent: Codable, Equatable, Sendable {
    var id: String
    var eventName: String
    var metadata: [String: JSONValue]
    var createdAt: Int64
    var token: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventName = "event_name"
        case metadata
        case createdAt = "created_at"
        case token
    }
}

private struct EventBatch: Encodable {
    struct Event: Encodable {
        var id: String
        var eventName: String
        var metadata: [String: JSONValue]
        var createdAt: Int64

        enum CodingKeys: String, CodingKey {
            case id
            case eventName = "event_name"
            case metadata
            case createdAt = "created_at"
        }
    }

    var sentAt: Int64
    var events: [Event]

    enum CodingKeys: String, CodingKey {
        case sentAt = "sent_at"
        case events
    }
}

@MainActor
final class EventQueue {
    static let maxQueue = 1000
    static let flushAt = 20
    static let flushInterval: Duration = .seconds(30)
    static let maxBatch = 100
    static let maxBackoff: Double = 300
    static let rateLimitWait: Double = 30

    private let fileURL: URL?
    private let client: APIClient
    private(set) var events: [QueuedEvent]
    private var token: String?
    private var timer: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var inFlight = false
    private var failures = 0
    private(set) var batchSize = EventQueue.maxBatch
    private var waitUntil = Date.distantPast
    private var reconnectObserver: (any NSObjectProtocol)?

    init(spaceID: String, appID: String, client: APIClient, directory: URL? = EventQueue.defaultDirectory) {
        self.client = client
        self.fileURL = directory?.appending(path: "events-\(spaceID)-\(appID).json")
        self.events = Self.load(from: fileURL)

        reconnectObserver = NotificationCenter.default.addObserver(
            forName: NetworkMonitor.didReconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.schedule(after: .seconds(1))
            }
        }
    }

    static var defaultDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = base.appending(path: "KaraDesk", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func setToken(_ token: String?) {
        self.token = token

        guard let token else {
            return
        }

        var claimed = false

        for index in events.indices where events[index].token == nil {
            events[index].token = token
            claimed = true
        }

        if claimed {
            scheduleSave()
        }

        if !events.isEmpty {
            schedule(after: .zero)
        }
    }

    func track(name: String, metadata: [String: JSONValue], at date: Date = Date()) {
        events.append(QueuedEvent(
            id: UUID().uuidString.lowercased(),
            eventName: name,
            metadata: metadata,
            createdAt: Int64(date.timeIntervalSince1970 * 1000),
            token: token
        ))

        if events.count > Self.maxQueue {
            events.removeFirst(events.count - Self.maxQueue)
        }

        scheduleSave()

        if sendable().count >= Self.flushAt {
            schedule(after: .zero)
        } else if timer == nil {
            schedule(after: Self.flushInterval)
        }
    }

    func flushInBackground() {
        save()

        guard !sendable().isEmpty else {
            return
        }

        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "KaraDesk events") {
            UIApplication.shared.endBackgroundTask(taskID)
            taskID = .invalid
        }

        Task {
            await flush()

            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
                taskID = .invalid
            }
        }
    }

    func flushSoon() {
        schedule(after: .zero)
    }

    private func sendable() -> [QueuedEvent] {
        guard let first = events.first(where: { $0.token != nil })?.token else {
            return []
        }

        return Array(events.filter { $0.token == first }.prefix(batchSize))
    }

    private func schedule(after delay: Duration) {
        timer?.cancel()

        let wait = max(delay, .milliseconds(Int(max(0, waitUntil.timeIntervalSinceNow) * 1000)))

        timer = Task { [weak self] in
            try? await Task.sleep(for: wait)

            guard !Task.isCancelled else {
                return
            }

            self?.timer = nil
            await self?.flush()
        }
    }

    func flush() async {
        guard !inFlight else {
            return
        }

        if waitUntil > Date() {
            schedule(after: .milliseconds(Int(waitUntil.timeIntervalSinceNow * 1000) + 10))
            return
        }

        guard NetworkMonitor.shared.isOnline else {
            return
        }

        let batch = sendable()

        guard let token = batch.first?.token else {
            return
        }

        inFlight = true
        let (status, retryAfter) = await send(batch, token: token)
        inFlight = false
        handle(batch, status: status, retryAfter: retryAfter)

        if !sendable().isEmpty {
            schedule(after: failures == 0 ? .zero : .milliseconds(Int(max(0, waitUntil.timeIntervalSinceNow) * 1000)))
        }
    }

    private func send(_ batch: [QueuedEvent], token: String) async -> (Int, String?) {
        let body = EventBatch(
            sentAt: Int64(Date().timeIntervalSince1970 * 1000),
            events: batch.map { .init(id: $0.id, eventName: $0.eventName, metadata: $0.metadata, createdAt: $0.createdAt) }
        )

        var request = URLRequest(url: client.baseURL.appending(path: "/v1/messenger/events"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await client.session.data(for: request)
            let http = response as? HTTPURLResponse
            return (http?.statusCode ?? 0, http?.value(forHTTPHeaderField: "Retry-After"))
        } catch {
            return (0, nil)
        }
    }

    func handle(_ batch: [QueuedEvent], status: Int, retryAfter: String?) {
        switch status {
        case 200 ..< 300:
            failures = 0
            batchSize = min(Self.maxBatch, batchSize * 2)
            remove(batch)
        case 400, 401, 403, 404:
            Log.network.error("Dropped \(batch.count) events the server refused (\(status))")
            remove(batch)
        case 413:
            if batch.count == 1 {
                remove(batch)
            }

            batchSize = max(1, batch.count / 2)
        case 429:
            failures += 1
            let seconds = Double(retryAfter ?? "").flatMap { $0 > 0 ? $0 : nil } ?? Self.rateLimitWait
            waitUntil = Date().addingTimeInterval(seconds)
        default:
            failures += 1
            let backoff = min(Self.maxBackoff, pow(2, Double(failures - 1)))
            waitUntil = Date().addingTimeInterval(backoff * Double.random(in: 0.5 ... 1.5))
        }
    }

    private func remove(_ batch: [QueuedEvent]) {
        let ids = Set(batch.map(\.id))
        events.removeAll { ids.contains($0.id) }
        scheduleSave()
    }

    private func scheduleSave() {
        guard saveTask == nil else {
            return
        }

        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.saveTask = nil
            self?.save()
        }
    }

    func save() {
        saveTask?.cancel()
        saveTask = nil

        guard let fileURL else {
            return
        }

        do {
            if events.isEmpty {
                try? FileManager.default.removeItem(at: fileURL)
            } else {
                try JSONEncoder().encode(events).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        } catch {
            Log.storage.error("Couldn't save queued events: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL?) -> [QueuedEvent] {
        guard let url, let data = try? Data(contentsOf: url) else {
            return []
        }

        return Array(((try? JSONDecoder().decode([QueuedEvent].self, from: data)) ?? []).suffix(maxQueue))
    }
}
