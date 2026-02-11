import Foundation

nonisolated struct StatusPreset: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var emoji: String        // Slack emoji code, e.g. ":house:"
    var displayEmoji: String // Unicode emoji for display, e.g. "🏠"
    var text: String         // Status text, e.g. "Working remotely"
    var expirationMinutes: Int // 0 = no expiration

    init(id: UUID = UUID(), emoji: String, displayEmoji: String, text: String, expirationMinutes: Int = 0) {
        self.id = id
        self.emoji = emoji
        self.displayEmoji = displayEmoji
        self.text = text
        self.expirationMinutes = expirationMinutes
    }

    var expirationLabel: String {
        if expirationMinutes == 0 { return "No expiration" }
        if expirationMinutes < 60 { return "\(expirationMinutes) min" }
        let hours = expirationMinutes / 60
        let mins = expirationMinutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}

// MARK: - Default Presets

extension StatusPreset {
    static let defaults: [StatusPreset] = [
        StatusPreset(emoji: ":house_with_garden:", displayEmoji: "🏡", text: "Working remotely"),
        StatusPreset(emoji: ":office:", displayEmoji: "🏢", text: "In the office"),
        StatusPreset(emoji: ":palm_tree:", displayEmoji: "🌴", text: "Vacationing", expirationMinutes: 0),
        StatusPreset(emoji: ":hamburger:", displayEmoji: "🍔", text: "Lunch break", expirationMinutes: 60),
        StatusPreset(emoji: ":headphones:", displayEmoji: "🎧", text: "Focus time — do not disturb", expirationMinutes: 120),
        StatusPreset(emoji: ":coffee:", displayEmoji: "☕", text: "Coffee break", expirationMinutes: 15),
        StatusPreset(emoji: ":bus:", displayEmoji: "🚌", text: "Commuting", expirationMinutes: 60),
        StatusPreset(emoji: ":face_with_thermometer:", displayEmoji: "🤒", text: "Out sick"),
        StatusPreset(emoji: ":calendar:", displayEmoji: "📅", text: "In a meeting", expirationMinutes: 30),
        StatusPreset(emoji: ":zzz:", displayEmoji: "💤", text: "Away"),
    ]
}
