//
//  Assertion.swift
//  LocalPasskeyManager
//
//  Created by Koji Murata on 2026/02/03.
//

import Foundation
import AuthenticationServices
import SwiftCBOR

func createPasskeyAssertionCredential(
    credentialID: Data, identity: ASPasskeyCredentialIdentity, clientDataHash: Data
) throws -> ASPasskeyAssertionCredential {
    let entry = try loadPasskeyEntry(credentialID: credentialID)
    let privateKey = try loadSecretKey(credentialID: credentialID)

    let newSignCount = entry.signCount + 1
    let authData = AuthenticatorData(
        relyingPartyIdentifier: identity.relyingPartyIdentifier,
        signCount: newSignCount,
        credentialData: nil
    )
    let authenticatorData = try authData.encode()

    var dataToSign = authenticatorData
    dataToSign.append(clientDataHash)

    let signature = try sign(data: dataToSign, with: privateKey)

    let updatedEntry = PasskeyEntry(
        relyingPartyIdentifier: entry.relyingPartyIdentifier,
        userName: entry.userName,
        userHandle: entry.userHandle,
        signCount: newSignCount
    )
    try updatePasskeyEntry(credentialID: credentialID, entry: updatedEntry)

    return ASPasskeyAssertionCredential(
        userHandle: identity.userHandle,
        relyingParty: identity.relyingPartyIdentifier,
        signature: signature,
        clientDataHash: clientDataHash,
        authenticatorData: authenticatorData,
        credentialID: credentialID
    )
}

private func loadPasskeyEntry(credentialID: Data) throws -> PasskeyEntry {
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecAttrAccessGroup: group,
        kSecUseDataProtectionKeychain: true,
        kSecReturnData: true,
    ] as CFDictionary

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query, &result)

    if status != errSecSuccess {
        throw CredentialProviderError.loadEntryFailed(status)
    }

    guard let data = result as? Data else {
        throw CredentialProviderError.unexpectedEntryData
    }

    let decoder = CodableCBORDecoder()
    return try decoder.decode(PasskeyEntry.self, from: data)
}

private func loadSecretKey(credentialID: Data) throws -> SecKey {
    let query = [
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: credentialID,
        kSecAttrAccessGroup: group,
        kSecUseDataProtectionKeychain: true,
        kSecReturnRef: true,
    ] as CFDictionary

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query, &result)

    if status != errSecSuccess {
        throw CredentialProviderError.loadKeyFailed(status)
    }

    return result as! SecKey
}

private func sign(data: Data, with privateKey: SecKey) throws -> Data {
    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
        privateKey,
        .ecdsaSignatureMessageX962SHA256,
        data as CFData,
        &error
    ) else {
        throw error!.takeRetainedValue()
    }
    return signature as Data
}

private func updatePasskeyEntry(credentialID: Data, entry: PasskeyEntry) throws {
    let encoder = CodableCBOREncoder()
    let entryData = try encoder.encode(entry)

    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecAttrAccessGroup: group,
        kSecUseDataProtectionKeychain: true,
    ] as CFDictionary

    let attributes = [
        kSecValueData: entryData,
    ] as CFDictionary

    let status = SecItemUpdate(query, attributes)
    if status != errSecSuccess {
        throw CredentialProviderError.updateEntryFailed(status)
    }
}
