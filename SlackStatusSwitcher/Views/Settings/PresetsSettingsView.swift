import SwiftUI

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

// MARK: - Add Preset Sheet

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
