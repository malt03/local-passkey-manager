//
//  ContentView.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/22.
//

import SwiftUI 

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [StoredPasskeyEntry] = []

    var body: some View {
        VStack {
            Text("Entry count: \(entries.count)")
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            do {
                entries = try listPasskeyEntries()
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

#Preview {
    ContentView()
}
