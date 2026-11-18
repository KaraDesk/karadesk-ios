import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    static let didReconnectNotification = Notification.Name("KaraDeskNetworkDidReconnect")

    var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied

            Task { @MainActor in
                if self?.isOnline != online {
                    self?.isOnline = online

                    if online {
                        NotificationCenter.default.post(name: NetworkMonitor.didReconnectNotification, object: nil)
                    }
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.karadesk.network-monitor"))
    }
}
