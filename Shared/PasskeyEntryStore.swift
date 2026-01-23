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

func deleteCredentialIdentity(credentialID: Data) throws {
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecAttrAccessGroup: group,
    ] as CFDictionary
    
    let status = SecItemDelete(query)
    if status != errSecSuccess && status != errSecItemNotFound {
        throw SharedError.deleteItemFailed(status)
    }
}
