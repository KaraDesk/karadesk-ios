import OSLog

enum Log {
    static let subsystem = "com.karadesk.sdk"

    static let session = Logger(subsystem: subsystem, category: "Session")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let realtime = Logger(subsystem: subsystem, category: "Realtime")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
}
