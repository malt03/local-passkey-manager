//
//  Registration.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/24.
//

import Foundation
import AuthenticationServices
import SwiftCBOR
import os

func createPasskeyRegistrationCredentialForPasskeyRegistration(
    credentialID: Data, identity: ASPasskeyCredentialIdentity, clientDataHash: Data
) throws -> ASPasskeyRegistrationCredential {
    let privateKey = try generateSecretKey(credentialID: credentialID)
    let attestationObject = try AttestationObject.createForPasskeyRegistration(
        credentialID: credentialID,
        relyingPartyIdentifier: identity.relyingPartyIdentifier,
        privateKey: privateKey
    )
    let encoder = CodableCBOREncoder()
    let attestationObjectData = try encoder.encode(attestationObject)

    return ASPasskeyRegistrationCredential(
        relyingParty: identity.relyingPartyIdentifier,
        clientDataHash: clientDataHash,
        credentialID: credentialID,
        attestationObject: attestationObjectData,
    )
}

private func generateSecretKey(credentialID: Data) throws -> SecKey {
    let accessControl = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .userPresence],
        nil
    )!

    let attributes = [
        kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits: 256,
        kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
        kSecPrivateKeyAttrs: [
            kSecAttrIsPermanent: true,
            kSecAttrApplicationTag: credentialID,
            kSecAttrAccessControl: accessControl,
            kSecAttrAccessGroup: group,
        ]
    ] as CFDictionary

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
        throw error!.takeRetainedValue()
    }
    
    return privateKey
}

extension AttestationObject {
    fileprivate static func createForPasskeyRegistration(
        credentialID: Data,
        relyingPartyIdentifier: String,
        privateKey: SecKey,
    ) throws -> AttestationObject {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CredentialProviderError.publicKeyExtractionFailed
        }

        let credentialData = AuthenticatorData.CredentialData(
            credentialID: credentialID, publicKey: publicKey
        )
        let authData = AuthenticatorData(
            relyingPartyIdentifier: relyingPartyIdentifier,
            signCount: 0, credentialData: credentialData
        )
        return try AttestationObject(authData: authData)
    }
}
