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
    @State private var entryToDelete: StoredPasskeyEntry?
    @State private var deleteConfirmationText = ""

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
                    .contextMenu(forSelectionType: StoredPasskeyEntry.ID.self) { selectedIDs in
                        if let id = selectedIDs.first,
                           let entry = entries.first(where: { $0.id == id }) {
                            Button("Open \"\(entry.entry.relyingPartyIdentifier)\"") {
                                if let url = URL(string: "https://\(entry.entry.relyingPartyIdentifier)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            Divider()
                            Button("Copy \"\(entry.entry.relyingPartyIdentifier)\"") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.entry.relyingPartyIdentifier, forType: .string)
                            }
                            Button("Copy \"\(entry.entry.userName)\"") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.entry.userName, forType: .string)
                            }
                            Divider()
                            Button("Delete \"\(entry.entry.relyingPartyIdentifier)\"", role: .destructive) {
                                entryToDelete = entry
                            }
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
        .alert("Delete Passkey", isPresented: .init(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil; deleteConfirmationText = "" } }
        )) {
            TextField("Type service name to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
                deleteConfirmationText = ""
            }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
            .disabled(deleteConfirmationText != entryToDelete?.entry.relyingPartyIdentifier)
        } message: {
            if let entry = entryToDelete {
                Text("To delete the passkey for \"\(entry.entry.relyingPartyIdentifier)\", type the service name below.")
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

    private func deleteEntry(_ stored: StoredPasskeyEntry) {
        Task {
            do {
                try await deletePasskey(credentialID: stored.credentialID, entry: stored.entry)
                entries.removeAll { $0.id == stored.id }
                selection = nil
                entryToDelete = nil
                deleteConfirmationText = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
