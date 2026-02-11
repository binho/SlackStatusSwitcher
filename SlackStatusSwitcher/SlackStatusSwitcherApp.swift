//
//  SlackStatusSwitcherApp.swift
//  SlackStatusSwitcher
//
//  Created by Cleber Santos on 2/10/26.
//

import SwiftUI
import Foundation

@main
struct SlackStatusSwitcherApp: App {
    @State private var viewModel = StatusViewModel()

    var body: some Scene {
        MenuBarExtra("Slack Status", systemImage: "bubble.left.fill") {
            StatusMenuView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
