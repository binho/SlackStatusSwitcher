import Foundation

actor SlackAPIService {
    static let shared = SlackAPIService()

    func getStatus(token: String) async throws -> SlackProfile {
        var request = URLRequest(url: URL(string: "https://slack.com/api/users.profile.get")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SlackProfileResponse.self, from: data)

        guard response.ok, let profile = response.profile else {
            throw NSError(domain: "SlackAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: response.error ?? "Unknown error"
            ])
        }
        return profile
    }

    func setStatus(token: String, statusText: String, statusEmoji: String, expiration: Int) async throws {
        var request = URLRequest(url: URL(string: "https://slack.com/api/users.profile.set")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let expirationTimestamp: Int
        if expiration > 0 {
            expirationTimestamp = Int(Date().timeIntervalSince1970) + (expiration * 60)
        } else {
            expirationTimestamp = 0
        }

        let body: [String: Any] = [
            "profile": [
                "status_text": statusText,
                "status_emoji": statusEmoji,
                "status_expiration": expirationTimestamp,
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SlackSetProfileResponse.self, from: data)

        guard response.ok else {
            throw NSError(domain: "SlackAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: response.error ?? "Unknown error"
            ])
        }
    }

    func clearStatus(token: String) async throws {
        try await setStatus(token: token, statusText: "", statusEmoji: "", expiration: 0)
    }
}
