//
//  PasskeyEntryStore.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/24.
//

import Foundation
import SwiftCBOR
import AuthenticationServices
import os

let group = "group.com.malt03.LocalPasskeyManager"
let logger = Logger(subsystem: "com.malt03.LocalPasskeyManager", category: "CredentialProvider")

enum SharedError: Error {
    case deleteItemFailed(OSStatus)
}
extension SharedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .deleteItemFailed(let osStatus):
            return "Delete item failed: \(osStatusToString(osStatus))"
        }
    }
}

func osStatusToString(_ osStatus: OSStatus) -> String {
    return SecCopyErrorMessageString(osStatus, nil) as String? ?? String(osStatus)
}

struct PasskeyEntry: Codable {
    let relyingPartyIdentifier: String
    let userName: String
    let userHandle: Data
    let signCount: UInt32
}

func deletePasskey(credentialID: Data, entry: PasskeyEntry) async throws {
    let identity = ASPasskeyCredentialIdentity(
        relyingPartyIdentifier: entry.relyingPartyIdentifier,
        userName: entry.userName,
        credentialID: credentialID,
        userHandle: entry.userHandle
    )

    var results = [
        Result { try deleteCredentialIdentity(credentialID: credentialID) },
        Result { try deleteSecretKey(credentialID: credentialID) },
    ]
    do {
        try await ASCredentialIdentityStore.shared.removeCredentialIdentities([identity])
        results.append(.success(()))
    } catch {
        results.append(.failure(error))
    }
    for result in results { try result.get() }
}

private func deleteCredentialIdentity(credentialID: Data) throws {
    try delete([
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecAttrAccessGroup: group,
        kSecUseDataProtectionKeychain: true,
    ] as CFDictionary)
}

private func deleteSecretKey(credentialID: Data) throws {
    try delete([
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: credentialID,
        kSecAttrAccessGroup: group,
        kSecUseDataProtectionKeychain: true,
    ] as CFDictionary)
}

private func delete(_ query: CFDictionary) throws {
    let status = SecItemDelete(query)
    if status != errSecSuccess && status != errSecItemNotFound {
        throw SharedError.deleteItemFailed(status)
    }
}
