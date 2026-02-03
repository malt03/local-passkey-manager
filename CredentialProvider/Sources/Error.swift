//
//  Error.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/24.
//

import AuthenticationServices

enum CredentialProviderError: Error {
    case setItemFailed(OSStatus)
    case unexpectedPublicKeyFormat(UInt8)
    case publicKeyExtractionFailed
    case unexpectedCredentialRequest(ASCredentialRequest?)
    case loadEntryFailed(OSStatus)
    case loadKeyFailed(OSStatus)
    case updateEntryFailed(OSStatus)
    case unexpectedEntryData
}

extension CredentialProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .setItemFailed(let osStatus):
            return "Failed to set item to keychain: \(osStatusToString(osStatus))"
        case .unexpectedPublicKeyFormat(let format):
            return "Unexpected public key format: \(format)"
        case .publicKeyExtractionFailed:
            return "Failed to extract public key"
        case .unexpectedCredentialRequest(let credentialRequest?):
            return "Unexpected credential request: \(credentialRequest)"
        case .unexpectedCredentialRequest(nil):
            return "Unexpected credential request: nil"
        case .loadEntryFailed(let osStatus):
            return "Failed to load entry from keychain: \(osStatusToString(osStatus))"
        case .loadKeyFailed(let osStatus):
            return "Failed to load key from keychain: \(osStatusToString(osStatus))"
        case .updateEntryFailed(let osStatus):
            return "Failed to update entry in keychain: \(osStatusToString(osStatus))"
        case .unexpectedEntryData:
            return "Unexpected entry data format"
        }
    }
}
