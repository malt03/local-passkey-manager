//
//  PasskeyEntryStoreForViewer.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/27.
//

import Foundation
import SwiftCBOR
import AuthenticationServices

enum ViewerError: Error {
    case queryFailed(OSStatus)
    case unexpectedResultType(CFTypeRef?)
    case unexpectedItem([String: Any])
}

extension ViewerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .queryFailed(let status):
            return "failed: \(osStatusToString(status))"
        case .unexpectedResultType(let ref):
            return "Unexpected result type: \(String(describing: ref))"
        case .unexpectedItem(let item):
            return "Unexpected item: \(item)"
        }
    }
}

struct StoredPasskeyEntry: Identifiable {
    var id: Data { credentialID }
    let credentialID: Data
    let entry: PasskeyEntry
    let creationDate: Date
}

func listPasskeyEntries() throws -> [StoredPasskeyEntry] {
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccessGroup: group,
        kSecMatchLimit: kSecMatchLimitAll,
        kSecReturnAttributes: true,
        kSecUseDataProtectionKeychain: true,
        kSecReturnData: true,
    ] as CFDictionary
    
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query, &result)
    
    if status == errSecItemNotFound {
        return []
    }
    
    if status != errSecSuccess {
        throw ViewerError.queryFailed(status)
    }
    guard let items = result as? [[String: Any]] else {
        throw ViewerError.unexpectedResultType(result)
    }
    
    let decoder = CodableCBORDecoder()
    return try items.map { item in
        guard let accountString = item[kSecAttrAccount as String] as? String,
              let credentialID = Data(base64Encoded: accountString),
              let entryData = item[kSecValueData as String] as? Data,
              let creationDate = item[kSecAttrCreationDate as String] as? Date
        else {
            throw ViewerError.unexpectedItem(item)
        }

        let entry = try decoder.decode(PasskeyEntry.self, from: entryData)
        return StoredPasskeyEntry(credentialID: credentialID, entry: entry, creationDate: creationDate)
    }
}

func syncCredentialIdentityStore(entries: [StoredPasskeyEntry]) async throws {
    let identities = entries.map { stored in
        ASPasskeyCredentialIdentity(
            relyingPartyIdentifier: stored.entry.relyingPartyIdentifier,
            userName: stored.entry.userName,
            credentialID: stored.credentialID,
            userHandle: stored.entry.userHandle
        )
    }
    try await ASCredentialIdentityStore.shared.replaceCredentialIdentities(identities)
}
