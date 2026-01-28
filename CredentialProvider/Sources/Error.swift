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
        }
    }
}
