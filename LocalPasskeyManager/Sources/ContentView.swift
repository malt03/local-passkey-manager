//
//  ContentView.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/22.
//

import SwiftUI

struct ContentView: View {
    @State private var entries: [StoredPasskeyEntry] = []
    @State private var sortOrder = [KeyPathComparator(\StoredPasskeyEntry.entry.relyingPartyIdentifier)]
    @State private var selection: StoredPasskeyEntry.ID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Passkeys",
                        systemImage: "key.slash",
                        description: Text("Registered passkeys will appear here.")
                    )
                } else {
                    Table(entries, selection: $selection, sortOrder: $sortOrder) {
                        TableColumn("Relying Party", value: \.entry.relyingPartyIdentifier)
                        TableColumn("User Name", value: \.entry.userName)
                        TableColumn("Created", value: \.creationDate) { stored in
                            Text(stored.creationDate, style: .date)
                        }
                    }
                    .onChange(of: sortOrder) {
                        entries.sort(using: sortOrder)
                    }
                }
            }
            .navigationTitle("Passkeys")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loadEntries()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func loadEntries() {
        do {
            entries = try listPasskeyEntries()
            entries.sort(using: sortOrder)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
