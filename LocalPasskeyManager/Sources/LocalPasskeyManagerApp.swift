//
//  LocalPasskeyManagerApp.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/22.
//

import SwiftUI

@main
struct LocalPasskeyManagerApp: App {
    @FocusState private var isSearchFocused: Bool

    var body: some Scene {
        WindowGroup {
            ContentView(isSearchFocused: $isSearchFocused)
        }
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Search") {
                    isSearchFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
