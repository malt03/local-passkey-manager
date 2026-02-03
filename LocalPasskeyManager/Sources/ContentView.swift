//
//  ContentView.swift
//  LocalPasskeyManager
//
//  Created by Koji Murata on 2026/01/22.
//

import SwiftUI

struct ContentView: View {
    @State private var entries: [StoredPasskeyEntry] = []
    @State private var sortOrder = [KeyPathComparator(\StoredPasskeyEntry.entry.relyingPartyIdentifier)]
    @State private var selection: StoredPasskeyEntry.ID?
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var entryToDelete: StoredPasskeyEntry?
    var isSearchFocused: FocusState<Bool>.Binding

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
                    PasskeyTableView(
                        entries: filteredEntries,
                        selection: $selection,
                        sortOrder: $sortOrder,
                        onDelete: { entryToDelete = $0 }
                    )
                    .onChange(of: sortOrder) {
                        entries.sort(using: sortOrder)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Filter by Service or User Name")
            .searchFocused(isSearchFocused)
            .navigationTitle("LocalPasskey")
        }
        .onAppear {
            loadEntries(first: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loadEntries(first: false)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .deleteConfirmation(entryToDelete: $entryToDelete) { entry in
            deleteEntry(entry)
        }
    }

    private func loadEntries(first: Bool) {
        do {
            entries = try listPasskeyEntries()
            entries.sort(using: sortOrder)
            if first {
                Task {
                    try? await syncCredentialIdentityStore(entries: entries)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEntry(_ stored: StoredPasskeyEntry) {
        do {
            try deletePasskey(credentialID: stored.credentialID)
            entries.removeAll { $0.id == stored.id }
            selection = nil
            // Use replaceCredentialIdentities instead of removeCredentialIdentities
            // because removeCredentialIdentities has a bug that removes all passkeys
            // for the same relyingPartyIdentifier, not just the specified one
            Task {
                try await syncCredentialIdentityStore(entries: entries)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
