import Foundation

extension KaraDesk {
    /// A metadata value for ``trackEvent(_:metadata:)``: text, a number, a true/false value, a date,
    /// nothing, a list of values or a group of named values.
    ///
    /// Write values as literals:
    ///
    /// ```swift
    /// KaraDesk.trackEvent("Placed order", metadata: [
    ///     "total": 49.99,
    ///     "express": true,
    ///     "items": [["sku": "A-100", "quantity": 2]],
    /// ])
    /// ```
    public indirect enum EventValue: Sendable, Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case date(Date)
        case null
        case array([EventValue])
        case object([String: EventValue])

        var json: JSONValue {
            switch self {
            case let .string(value):
                .string(value)
            case let .number(value):
                value.isFinite ? .number(value) : .null
            case let .bool(value):
                .bool(value)
            case let .date(value):
                .string(value.formatted(.iso8601))
            case .null:
                .null
            case let .array(values):
                .array(values.map(\.json))
            case let .object(values):
                .object(values.mapValues(\.json))
            }
        }
    }

    /// Records something the user did in your app, like "Created project" or "Upgraded plan".
    ///
    /// Events show on the person's profile in KaraDesk with how many times they did it and when.
    /// They're saved on the device and sent in batches, so you can track as often as you like:
    /// events tracked while offline are sent when the connection comes back.
    ///
    /// Call ``initialize(spaceID:appID:)`` first. Events belong to whoever is signed in when you
    /// track them, or to the anonymous visitor until they sign in.
    ///
    /// - Parameters:
    ///   - name: What happened, up to 120 characters. Past-tense names like "Invited teammate" read best.
    ///   - metadata: Up to 20 details about the event. Values can be lists or groups of values, nested
    ///     up to 3 levels, with up to 50 items in a list and 8 KB in all. Text can be up to 500 characters.
    public static func trackEvent(_ name: String, metadata: [String: EventValue] = [:]) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let store else {
            Log.session.error("Call KaraDesk.initialize(spaceID:appID:) before tracking events")
            return
        }

        guard !name.isEmpty, name.count <= 120 else {
            Log.session.error("Event names must be 1 to 120 characters")
            return
        }

        store.events.track(name: name, metadata: metadata.mapValues(\.json))
    }
}

extension KaraDesk.EventValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension KaraDesk.EventValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension KaraDesk.EventValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension KaraDesk.EventValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension KaraDesk.EventValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension KaraDesk.EventValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: KaraDesk.EventValue...) {
        self = .array(elements)
    }
}

extension KaraDesk.EventValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, KaraDesk.EventValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
