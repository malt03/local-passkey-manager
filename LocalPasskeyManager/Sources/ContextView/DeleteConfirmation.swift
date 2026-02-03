//
//  DeleteConfirmation.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/02/03.
//

import SwiftUI

struct DeleteConfirmationModifier: ViewModifier {
    @Binding var entryToDelete: StoredPasskeyEntry?
    @State private var confirmationText = ""
    let onDelete: (StoredPasskeyEntry) -> Void
    
    private var serviceName: String {
        entryToDelete?.entry.relyingPartyIdentifier ?? ""
    }
    
    func body(content: Content) -> some View {
        content
            .alert("Delete Passkey", isPresented: .init(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil; confirmationText = "" } }
            )) {
                TextField("Type service name to confirm", text: $confirmationText)
                Button("Cancel", role: .cancel) {
                    entryToDelete = nil
                    confirmationText = ""
                }
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        onDelete(entry)
                        entryToDelete = nil
                        confirmationText = ""
                    }
                }
                .disabled(confirmationText != serviceName)
            } message: {
                Text("To delete the passkey for \"\(serviceName)\", type the service name below.")
            }
    }
}

extension View {
    func deleteConfirmation(
        entryToDelete: Binding<StoredPasskeyEntry?>,
        onDelete: @escaping (StoredPasskeyEntry) -> Void
    ) -> some View {
        modifier(DeleteConfirmationModifier(entryToDelete: entryToDelete, onDelete: onDelete))
    }
}
