import SwiftUI
import Foundation

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
