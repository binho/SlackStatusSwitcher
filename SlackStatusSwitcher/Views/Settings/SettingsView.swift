import SwiftUI

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
