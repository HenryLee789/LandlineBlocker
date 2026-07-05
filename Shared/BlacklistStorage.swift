import Foundation

public enum BlacklistStorageError: LocalizedError, Sendable {
    case appGroupUnavailable(String)
    case cannotReadData(URL)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "无法访问 App Group：\(identifier)。请检查主 App 和 Extension 是否都启用了同一个 App Group。"
        case .cannotReadData(let url):
            return "无法读取黑名单文件：\(url.lastPathComponent)"
        }
    }
}

public enum BlacklistStorage {
    public static func loadThrowing() throws -> [BlockedNumberRecord] {
        let url = try blacklistFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([BlockedNumberRecord].self, from: data)
    }

    public static func loadOrEmpty() -> [BlockedNumberRecord] {
        do {
            return try loadThrowing()
        } catch {
            #if DEBUG
            print("[LandlineBlocker] loadOrEmpty fallback: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    public static func save(_ records: [BlockedNumberRecord]) throws {
        let url = try blacklistFileURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        try data.write(to: url, options: [.atomic])
    }

    public static func blacklistFileURL() throws -> URL {
        try appGroupContainerURL().appendingPathComponent(SharedConfig.blacklistFileName, isDirectory: false)
    }

    public static func appGroupContainerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConfig.appGroupIdentifier) else {
            throw BlacklistStorageError.appGroupUnavailable(SharedConfig.appGroupIdentifier)
        }
        return url
    }
}
