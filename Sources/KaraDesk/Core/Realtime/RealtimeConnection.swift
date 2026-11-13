import Foundation

actor RealtimeConnection {
    static let unauthorizedCloseCode = 4401

    private let url: URL
    private let session: URLSession
    private let continuation: AsyncStream<RealtimeEvent>.Continuation
    private var task: URLSessionWebSocketTask?
    private var loop: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var attempt = 0

    nonisolated let events: AsyncStream<RealtimeEvent>

    init(baseURL: URL, token: String, session: URLSession = .karaDesk) {
        var components = URLComponents(url: baseURL.appending(path: "/v1/realtime"), resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "http" ? "ws" : "wss"
        components?.queryItems = [
            URLQueryItem(name: "kind", value: "messenger"),
            URLQueryItem(name: "token", value: token),
        ]

        self.url = components?.url ?? baseURL
        self.session = session
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(100))
    }

    func start() {
        guard loop == nil else {
            return
        }

        loop = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        heartbeat?.cancel()
        heartbeat = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        continuation.finish()
    }

    func sendTyping(conversationID: Int) {
        send(["type": .string("typing"), "conversation_id": .number(Double(conversationID))])
    }

    static func backoff(attempt: Int) -> Duration {
        let base = min(30.0, pow(2.0, Double(min(attempt, 5))))
        let jitter = Double.random(in: 0 ... 0.3) * base
        return .milliseconds(Int((base + jitter) * 1000))
    }

    private func run() async {
        while !Task.isCancelled {
            let socket = session.webSocketTask(with: url)
            task = socket
            socket.resume()
            startHeartbeat()

            let closeCode = await receive(on: socket)

            heartbeat?.cancel()
            heartbeat = nil

            if Task.isCancelled {
                return
            }

            if closeCode == Self.unauthorizedCloseCode {
                continuation.yield(.unauthorized)
                continuation.finish()
                return
            }

            attempt += 1
            try? await Task.sleep(for: Self.backoff(attempt: attempt))
        }
    }

    private func receive(on socket: URLSessionWebSocketTask) async -> Int? {
        while !Task.isCancelled {
            do {
                let message = try await socket.receive()
                attempt = 0

                let data: Data? = switch message {
                case let .data(data):
                    data
                case let .string(text):
                    Data(text.utf8)
                @unknown default:
                    nil
                }

                if let data, let event = RealtimeEvent.decode(data) {
                    continuation.yield(event)
                }
            } catch {
                Log.realtime.debug("Socket closed: \(error.localizedDescription, privacy: .public)")
                return socket.closeCode == .invalid ? nil : socket.closeCode.rawValue
            }
        }

        return nil
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))

                if Task.isCancelled {
                    return
                }

                await self?.send(["type": .string("ping")])
            }
        }
    }

    private func send(_ payload: [String: JSONValue]) {
        guard let task, let data = try? JSONEncoder().encode(payload), let text = String(data: data, encoding: .utf8) else {
            return
        }

        task.send(.string(text)) { error in
            if let error {
                Log.realtime.debug("Send failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
