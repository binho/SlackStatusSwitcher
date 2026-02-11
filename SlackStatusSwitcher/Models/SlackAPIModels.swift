import Foundation

nonisolated struct SlackProfileResponse: Codable, Sendable {
    let ok: Bool
    let error: String?
    let profile: SlackProfile?
}

nonisolated struct SlackProfile: Codable, Sendable {
    let statusText: String?
    let statusEmoji: String?
    let statusExpiration: Int?

    enum CodingKeys: String, CodingKey {
        case statusText = "status_text"
        case statusEmoji = "status_emoji"
        case statusExpiration = "status_expiration"
    }
}

nonisolated struct SlackSetProfileResponse: Codable, Sendable {
    let ok: Bool
    let error: String?
}
