import Foundation

nonisolated struct Workspace: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var token: String // xoxp-... user OAuth token

    init(id: UUID = UUID(), name: String, token: String) {
        self.id = id
        self.name = name
        self.token = token
    }
}
