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
