import SwiftUI

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

// MARK: - Status Row

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

// MARK: - Results Banner

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
