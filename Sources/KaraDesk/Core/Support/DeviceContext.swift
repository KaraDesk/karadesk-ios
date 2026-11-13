import Foundation
import UIKit

enum DeviceContext {
    @MainActor
    static func current(bundle: Bundle = .main) -> BootRequest.Device {
        BootRequest.Device(
            os: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            deviceModel: modelIdentifier(),
            appVersion: appVersion(bundle: bundle),
            sdkVersion: SDKVersion.current,
            language: Locale.preferredLanguages.first,
            timezone: TimeZone.current.identifier
        )
    }

    @MainActor
    static func userAgent(bundle: Bundle = .main) -> String {
        let app = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
        let version = appVersion(bundle: bundle) ?? "unknown"
        return "KaraDesk-iOS/\(SDKVersion.current) (\(app) \(version); iOS \(UIDevice.current.systemVersion); \(modelIdentifier()))"
    }

    static func appVersion(bundle: Bundle) -> String? {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where version != build:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        case let (nil, build?):
            return build
        default:
            return nil
        }
    }

    static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }

        var system = utsname()
        uname(&system)

        return withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
