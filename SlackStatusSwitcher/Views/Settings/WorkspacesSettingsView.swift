import SwiftUI

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

// MARK: - Add Workspace Sheet

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
