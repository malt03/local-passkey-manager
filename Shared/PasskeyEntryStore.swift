//
//  PasskeyEntryStore.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/24.
//

import Foundation

let group = "group.com.malt03.LocalPasskeyManager"

enum SharedError: Error {
    case deleteItemFailed(OSStatus)
}

struct PasskeyEntry: Codable {
    let relyingPartyIdentifier: String
    let userName: String
    let userHandle: Data
    let signCount: UInt32
}

func deletePasskey(credentialID: Data) throws {
    let results = [
        Result { try deleteCredentialIdentity(credentialID: credentialID) },
        Result { try deleteSecretKey(credentialID: credentialID) },
    ]
    for result in results { try result.get() }
}

private func deleteCredentialIdentity(credentialID: Data) throws {
    try delete([
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecAttrAccessGroup: group,
    ] as CFDictionary)
}

private func deleteSecretKey(credentialID: Data) throws {
    try delete([
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: credentialID,
        kSecAttrAccessGroup: group,
    ] as CFDictionary)
}

private func delete(_ query: CFDictionary) throws {
    let status = SecItemDelete(query)
    if status != errSecSuccess && status != errSecItemNotFound {
        throw SharedError.deleteItemFailed(status)
    }
}
