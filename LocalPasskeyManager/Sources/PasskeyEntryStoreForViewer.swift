//
//  PasskeyEntryStoreForViewer.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/27.
//

import Foundation
import SwiftCBOR

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

struct StoredPasskeyEntry {
    let credentialID: Data
    let entry: PasskeyEntry
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
              let entryData = item[kSecValueData as String] as? Data
        else {
            throw ViewerError.unexpectedItem(item)
        }
        
        let entry = try decoder.decode(PasskeyEntry.self, from: entryData)
        return StoredPasskeyEntry(credentialID: credentialID, entry: entry)
    }
}
