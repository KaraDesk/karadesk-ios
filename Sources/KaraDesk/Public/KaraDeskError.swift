import Foundation

/// An error reported by the KaraDesk SDK.
public enum KaraDeskError: Error, Sendable, Equatable {
    /// ``KaraDesk/initialize(spaceID:appID:)`` has not been called yet.
    case notInitialized

    /// ``KaraDesk/updateUser(_:)`` was called while no user is signed in.
    case notLoggedIn

    /// The space or app identifier passed to ``KaraDesk/initialize(spaceID:appID:)`` is empty.
    case invalidConfiguration

    /// Your app requires identity verification and the user hash is missing or does not match.
    case identityVerificationFailed(String)

    /// The messenger is turned off for this audience, or your KaraDesk subscription is inactive.
    case unavailable(String)

    /// The device could not reach KaraDesk.
    case network(URLError.Code)

    /// KaraDesk returned an error.
    case server(statusCode: Int, message: String)

    /// KaraDesk returned a response this version of the SDK could not read.
    case unexpectedResponse
}

extension KaraDeskError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "KaraDesk.initialize(spaceID:appID:) must be called before using the messenger."
        case .notLoggedIn:
            return "KaraDesk.login(_:) must be called before KaraDesk.updateUser(_:)."
        case .invalidConfiguration:
            return "The KaraDesk space ID and app ID must not be empty."
        case let .identityVerificationFailed(message), let .unavailable(message):
            return message
        case let .network(code) where KaraDeskError.offlineCodes.contains(code):
            return String(localized: "error.offline", defaultValue: "You're offline. Check your connection and try again.", bundle: .module)
        case .network(.timedOut):
            return String(localized: "error.timeout", defaultValue: "This is taking longer than usual. Please try again.", bundle: .module)
        case .network:
            return String(localized: "error.network", defaultValue: "Can't connect right now. Check your connection and try again.", bundle: .module)
        case let .server(statusCode, _) where statusCode >= 500:
            return String(localized: "error.server", defaultValue: "Something went wrong on our end. Please try again.", bundle: .module)
        case let .server(_, message):
            return message
        case .unexpectedResponse:
            return String(localized: "error.unexpected", defaultValue: "Something went wrong. Please try again.", bundle: .module)
        }
    }
}

extension KaraDeskError {
    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .dataNotAllowed,
        .internationalRoamingOff,
        .callIsActive,
    ]

    /// Whether the device has no usable internet connection.
    public var isOffline: Bool {
        if case let .network(code) = self {
            return Self.offlineCodes.contains(code)
        }

        return false
    }

    var isCancelled: Bool {
        self == .network(.cancelled)
    }

    /// Whether trying the same request again might succeed.
    public var isRetryable: Bool {
        switch self {
        case .network, .server, .unexpectedResponse:
            return true
        default:
            return false
        }
    }
}
