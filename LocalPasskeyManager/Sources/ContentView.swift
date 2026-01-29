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
    @State private var searchText = ""

    private var filteredEntries: [StoredPasskeyEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { stored in
            stored.entry.relyingPartyIdentifier.localizedCaseInsensitiveContains(searchText) ||
            stored.entry.userName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Passkeys",
                        systemImage: "key.slash",
                        description: Text("Registered passkeys will appear here.")
                    )
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Table(filteredEntries, selection: $selection, sortOrder: $sortOrder) {
                        TableColumn("Service", value: \.entry.relyingPartyIdentifier)
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
            .searchable(text: $searchText, prompt: "Filter by Service or User Name")
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
