import Foundation

public struct BlockedNumberRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let raw: String
    public let normalized: String
    public let createdAt: Date

    public init(id: UUID = UUID(), raw: String, normalized: String, createdAt: Date = Date()) {
        self.id = id
        self.raw = raw
        self.normalized = normalized
        self.createdAt = createdAt
    }
}
