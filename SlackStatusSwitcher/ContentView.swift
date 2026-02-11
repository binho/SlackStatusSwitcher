// SlackStatusSwitcher - A macOS menu bar app to set your Slack status across multiple workspaces
//
// PROJECT SETUP:
// 1. Create a new macOS App project in Xcode (SwiftUI, Swift)
// 2. Replace the contents of your main App file with this code
// 3. In your target's Info.plist, add: "Application is agent (UIElement)" = YES
//    (This hides the dock icon so it runs as a pure menu bar app)
//
// SLACK APP SETUP (repeat for each workspace):
// 1. Go to https://api.slack.com/apps → Create New App → From Scratch
// 2. Name it (e.g. "Status Switcher"), pick your workspace
// 3. Go to OAuth & Permissions → User Token Scopes → Add:
//    - users.profile:read
//    - users.profile:write
// 4. Install to Workspace → Copy the "User OAuth Token" (xoxp-...)
// 5. Add that token in the app's Settings panel
//
// FILE STRUCTURE (if you want to split into files):
//   - SlackStatusSwitcherApp.swift  (App entry point)
//   - Models.swift                  (StatusPreset, Workspace, etc.)
//   - SlackAPIService.swift         (API calls)
//   - ViewModels.swift              (StatusViewModel)
//   - Views/StatusMenuView.swift
//   - Views/SettingsView.swift
//   - Views/AddWorkspaceView.swift
//
// For simplicity, everything is in one file below.

import SwiftUI
import Foundation
import Security

// MARK: - Models

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

nonisolated enum StatusUpdateResult: Identifiable, Sendable {
    case success(workspaceName: String)
    case failure(workspaceName: String, error: String)

    var id: String {
        switch self {
        case .success(let name): return "success-\(name)"
        case .failure(let name, _): return "failure-\(name)"
        }
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

// MARK: - Keychain Helper (secure token storage)

nonisolated struct KeychainHelper {
    static let service = "com.slackstatusswitcher.workspaces"

    static func save(workspaces: [Workspace]) {
        guard let data = try? JSONEncoder().encode(workspaces) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "workspaces",
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func loadWorkspaces() -> [Workspace] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "workspaces",
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return [] }
        return (try? JSONDecoder().decode([Workspace].self, from: data)) ?? []
    }
}

// MARK: - Slack API Service

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

// MARK: - ViewModel

@MainActor
@Observable
class StatusViewModel {
    var presets: [StatusPreset] = StatusPreset.defaults
    var workspaces: [Workspace] = []
    var isUpdating = false
    var lastResults: [StatusUpdateResult] = []
    var showResults = false
    var currentStatusText: String = ""
    var currentStatusEmoji: String = ""

    private let presetsKey = "StatusPresets"

    init() {
        loadWorkspaces()
        loadPresets()
        Task { await fetchCurrentStatus() }
    }

    // MARK: Persistence

    func loadWorkspaces() {
        workspaces = KeychainHelper.loadWorkspaces()
    }

    func saveWorkspaces() {
        KeychainHelper.save(workspaces: workspaces)
    }

    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let saved = try? JSONDecoder().decode([StatusPreset].self, from: data) {
            presets = saved
        }
    }

    func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    // MARK: Workspace Management

    func addWorkspace(name: String, token: String) {
        let ws = Workspace(name: name, token: token)
        workspaces.append(ws)
        saveWorkspaces()
    }

    func removeWorkspace(_ workspace: Workspace) {
        workspaces.removeAll { $0.id == workspace.id }
        saveWorkspaces()
    }

    // MARK: Preset Management

    func addPreset(_ preset: StatusPreset) {
        presets.append(preset)
        savePresets()
    }

    func removePreset(_ preset: StatusPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    func movePreset(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }

    // MARK: Status Actions

    func fetchCurrentStatus() async {
        guard let firstWorkspace = workspaces.first else { return }
        do {
            let profile = try await SlackAPIService.shared.getStatus(token: firstWorkspace.token)
            currentStatusText = profile.statusText ?? ""
            currentStatusEmoji = profile.statusEmoji ?? ""
        } catch {
            print("Failed to fetch status: \(error)")
        }
    }

    func applyStatus(_ preset: StatusPreset) async {
        guard !workspaces.isEmpty else { return }
        isUpdating = true
        lastResults = []

        let results = await withTaskGroup(of: StatusUpdateResult.self, returning: [StatusUpdateResult].self) { group in
            for ws in workspaces {
                group.addTask {
                    do {
                        try await SlackAPIService.shared.setStatus(
                            token: ws.token,
                            statusText: preset.text,
                            statusEmoji: preset.emoji,
                            expiration: preset.expirationMinutes
                        )
                        return .success(workspaceName: ws.name)
                    } catch {
                        return .failure(workspaceName: ws.name, error: error.localizedDescription)
                    }
                }
            }
            var collected: [StatusUpdateResult] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        lastResults = results

        currentStatusText = preset.text
        currentStatusEmoji = preset.displayEmoji
        isUpdating = false
        showResults = true

        // Auto-hide results after 3 seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        showResults = false
    }

    func clearStatus() async {
        guard !workspaces.isEmpty else { return }
        isUpdating = true
        lastResults = []

        let results = await withTaskGroup(of: StatusUpdateResult.self, returning: [StatusUpdateResult].self) { group in
            for ws in workspaces {
                group.addTask {
                    do {
                        try await SlackAPIService.shared.clearStatus(token: ws.token)
                        return .success(workspaceName: ws.name)
                    } catch {
                        return .failure(workspaceName: ws.name, error: error.localizedDescription)
                    }
                }
            }
            var collected: [StatusUpdateResult] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        lastResults = results

        currentStatusText = ""
        currentStatusEmoji = ""
        isUpdating = false
        showResults = true

        try? await Task.sleep(nanoseconds: 3_000_000_000)
        showResults = false
    }
}

// MARK: - Menu Bar View

struct StatusMenuView: View {
    var viewModel: StatusViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with current status
            VStack(alignment: .leading, spacing: 4) {
                Text("Slack Status Switcher")
                    .font(.headline)

                if viewModel.isUpdating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text("Updating status…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !viewModel.currentStatusText.isEmpty {
                    HStack(spacing: 4) {
                        Text("Current:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.currentStatusEmoji) \(viewModel.currentStatusText)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                } else {
                    Text("No status set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if viewModel.workspaces.isEmpty {
                    Text("⚠️ No workspaces configured. Open Settings to add one.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                } else {
                    Text("\(viewModel.workspaces.count) workspace\(viewModel.workspaces.count == 1 ? "" : "s") connected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Status presets list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(viewModel.presets) { preset in
                        StatusRow(preset: preset, disabled: viewModel.isUpdating) {
                            Task { await viewModel.applyStatus(preset) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 350)

            Divider()

            // Result feedback
            if viewModel.showResults {
                ResultsBanner(results: viewModel.lastResults)
                Divider()
            }

            // Bottom actions
            HStack {
                Button {
                    Task { await viewModel.clearStatus() }
                } label: {
                    Label("Clear Status", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUpdating || viewModel.workspaces.isEmpty)

                Spacer()

                Button {
                    NSApplication.shared.activate()
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }
}

struct StatusRow: View {
    let preset: StatusPreset
    let disabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(preset.displayEmoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.text)
                        .font(.body)
                        .lineLimit(1)

                    if preset.expirationMinutes > 0 {
                        Text(preset.expirationLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in isHovered = hovering }
        .padding(.horizontal, 4)
    }
}

struct ResultsBanner: View {
    let results: [StatusUpdateResult]

    private var allSuccess: Bool {
        results.allSatisfy {
            if case .success = $0 { return true }
            return false
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: allSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(allSuccess ? .green : .orange)
                .font(.caption)

            if allSuccess {
                Text("Updated \(results.count) workspace\(results.count == 1 ? "" : "s")")
                    .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(results) { result in
                        switch result {
                        case .success(let name):
                            Text("✓ \(name)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        case .failure(let name, let error):
                            Text("✗ \(name): \(error)")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .transition(.opacity)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var viewModel: StatusViewModel
    @State private var selectedTab = "workspaces"

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkspacesSettingsView(viewModel: viewModel)
                .tabItem { Label("Workspaces", systemImage: "building.2") }
                .tag("workspaces")

            PresetsSettingsView(viewModel: viewModel)
                .tabItem { Label("Status Presets", systemImage: "list.bullet") }
                .tag("presets")
        }
        .frame(width: 550, height: 420)
        .padding()
    }
}

// MARK: - Workspaces Settings

struct WorkspacesSettingsView: View {
    var viewModel: StatusViewModel
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Workspaces")
                .font(.title3)
                .bold()

            Text("Add your Slack User OAuth tokens (xoxp-...) for each workspace. Tokens are stored securely in your macOS Keychain.")
                .font(.caption)
                .foregroundColor(.secondary)

            if viewModel.workspaces.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No workspaces added yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.workspaces) { ws in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ws.name)
                                    .font(.body)
                                Text("xoxp-••••\(String(ws.token.suffix(8)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeWorkspace(ws)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Workspace", systemImage: "plus")
                }
                .sheet(isPresented: $showAddSheet) {
                    AddWorkspaceView(viewModel: viewModel, isPresented: $showAddSheet)
                }
            }
        }
    }
}

struct AddWorkspaceView: View {
    var viewModel: StatusViewModel
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var token = ""
    @State private var isTesting = false
    @State private var testResult: String?

    var isValid: Bool {
        !name.isEmpty && token.hasPrefix("xoxp-")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Slack Workspace")
                .font(.title3)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("Workspace Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. My Company", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("User OAuth Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("xoxp-...", text: $token)
                    .textFieldStyle(.roundedBorder)
                Text("Get this from your Slack App → OAuth & Permissions → User OAuth Token")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let testResult {
                Text(testResult)
                    .font(.caption)
                    .foregroundColor(testResult.contains("✓") ? .green : .red)
            }

            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled(!isValid || isTesting)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    viewModel.addWorkspace(name: name, token: token)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let profile = try await SlackAPIService.shared.getStatus(token: token)
                await MainActor.run {
                    testResult = "✓ Connected! Current status: \(profile.statusEmoji ?? "") \(profile.statusText ?? "(none)")"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ Failed: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Presets Settings

struct PresetsSettingsView: View {
    var viewModel: StatusViewModel
    @State private var showAddPreset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Presets")
                .font(.title3)
                .bold()

            Text("Customize your quick-switch statuses. Drag to reorder.")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(viewModel.presets) { preset in
                    HStack(spacing: 10) {
                        Text(preset.displayEmoji)
                            .font(.title3)

                        VStack(alignment: .leading) {
                            Text(preset.text)
                                .font(.body)
                            HStack(spacing: 8) {
                                Text(preset.emoji)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if preset.expirationMinutes > 0 {
                                    Text("• \(preset.expirationLabel)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            viewModel.removePreset(preset)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    viewModel.movePreset(from: source, to: destination)
                }
            }

            HStack {
                Button("Reset to Defaults") {
                    viewModel.presets = StatusPreset.defaults
                    viewModel.savePresets()
                }

                Spacer()

                Button {
                    showAddPreset = true
                } label: {
                    Label("Add Preset", systemImage: "plus")
                }
                .sheet(isPresented: $showAddPreset) {
                    AddPresetView(viewModel: viewModel, isPresented: $showAddPreset)
                }
            }
        }
    }
}

struct AddPresetView: View {
    var viewModel: StatusViewModel
    @Binding var isPresented: Bool

    @State private var displayEmoji = "😊"
    @State private var slackEmoji = ":smile:"
    @State private var text = ""
    @State private var hasExpiration = false
    @State private var expirationMinutes = 30

    let expirationOptions = [15, 30, 60, 120, 240, 480]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Status Preset")
                .font(.title3)
                .bold()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Emoji")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("🏠", text: $displayEmoji)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Slack Emoji Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(":house:", text: $slackEmoji)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status Text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Working remotely", text: $text)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Auto-expire", isOn: $hasExpiration)

            if hasExpiration {
                Picker("Expires after", selection: $expirationMinutes) {
                    ForEach(expirationOptions, id: \.self) { mins in
                        if mins < 60 {
                            Text("\(mins) minutes").tag(mins)
                        } else {
                            Text("\(mins / 60) hour\(mins / 60 == 1 ? "" : "s")").tag(mins)
                        }
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let preset = StatusPreset(
                        emoji: slackEmoji,
                        displayEmoji: displayEmoji,
                        text: text,
                        expirationMinutes: hasExpiration ? expirationMinutes : 0
                    )
                    viewModel.addPreset(preset)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty || slackEmoji.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
