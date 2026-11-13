import Foundation

enum Coding {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            guard let date = parseDate(value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date: \(value)"
                )
            }

            return date
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(.iso8601))
        }
        return encoder
    }

    static func parseDate(_ value: String) -> Date? {
        if let date = try? Date(value, strategy: fractionalISO8601) {
            return date
        }

        return try? Date(value, strategy: .iso8601)
    }

    private static let fractionalISO8601 = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}

extension KeyedDecodingContainer {
    func decode<Value: Decodable>(_ key: Key, default fallback: Value) -> Value {
        (try? decodeIfPresent(Value.self, forKey: key)) ?? fallback
    }

    func decodeLenient<Value: Decodable>(_ key: Key) -> Value? {
        (try? decodeIfPresent(Value.self, forKey: key)) ?? nil
    }

    func decodeURL(_ key: Key) -> URL? {
        guard let string = decodeLenient(key) as String?, !string.isEmpty else {
            return nil
        }

        return URL(string: string)
    }

    func decodeLossyArray<Element: Decodable>(_ key: Key) -> [Element] {
        guard let items = try? decodeIfPresent([Lossy<Element>].self, forKey: key) else {
            return []
        }

        return items.compactMap(\.value)
    }
}

struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}
