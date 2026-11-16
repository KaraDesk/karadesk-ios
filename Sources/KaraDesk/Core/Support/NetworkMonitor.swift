import Network
import Observation

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied

            Task { @MainActor in
                if self?.isOnline != online {
                    self?.isOnline = online
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.karadesk.network-monitor"))
    }
}
