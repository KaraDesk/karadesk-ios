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
        case .network:
            return String(localized: "error.network", defaultValue: "Can't connect right now. Check your connection and try again.", bundle: .module)
        case let .server(_, message):
            return message
        case .unexpectedResponse:
            return String(localized: "error.unexpected", defaultValue: "Something went wrong. Please try again.", bundle: .module)
        }
    }
}
