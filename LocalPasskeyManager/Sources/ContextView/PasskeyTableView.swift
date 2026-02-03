//
//  PasskeyTableView.swift
//  LocalPasskeyManager
//
//  Created by Koji Murata on 2026/02/03.
//

import SwiftUI

struct PasskeyTableView: View {
    let entries: [StoredPasskeyEntry]
    @Binding var selection: StoredPasskeyEntry.ID?
    @Binding var sortOrder: [KeyPathComparator<StoredPasskeyEntry>]
    let onDelete: (StoredPasskeyEntry) -> Void

    var body: some View {
        Table(entries, selection: $selection, sortOrder: $sortOrder) {
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
                    onDelete(entry)
                }
            }
        }
        .onCopyCommand {
            guard let id = selection,
                  let entry = entries.first(where: { $0.id == id }) else {
                return []
            }
            let item = NSItemProvider(object: entry.entry.relyingPartyIdentifier as NSString)
            return [item]
        }
        .onDeleteCommand {
            guard let id = selection,
                  let entry = entries.first(where: { $0.id == id }) else {
                return
            }
            onDelete(entry)
        }
    }
}
