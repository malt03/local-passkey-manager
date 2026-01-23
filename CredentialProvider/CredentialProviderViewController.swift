//
//  CredentialProviderViewController.swift
//  CredentialProvider
//
//  Created by 村田紘司 on 2026/01/22.
//

import AuthenticationServices
import os
import CryptoKit
import SwiftCBOR

private let logger = Logger(subsystem: "com.malt03.LocalPasskeyManager", category: "CredentialProvider")

class CredentialProviderViewController: ASCredentialProviderViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("viewDidLoad")
    }
    
    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        func failed(_ error: Error) {
            let alert = NSAlert(error: error)
            alert.runModal()
            extensionContext.cancelRequest(
                withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
            )
        }

        guard
            let passkeyRequest = registrationRequest as? ASPasskeyCredentialRequest,
            let identity = passkeyRequest.credentialIdentity as? ASPasskeyCredentialIdentity
        else {
            failed(CredentialProviderError.unexpectedCredentialRequest(registrationRequest))
            return
        }
        
        let credentialID = Data((0..<16).map { _ in UInt8.random(in: 0...UInt8.max) })
        
        do {
            let response = try createPasskeyRegistrationCredentialForPasskeyRegistration(
                credentialID: credentialID, identity: identity, clientDataHash: passkeyRequest.clientDataHash
            )
            try saveCredentialIdentity(credentialID: credentialID, identity: identity)

            Task {
                do {
                    try await storeToCredentialIdentityStore(credentialID: credentialID, identity: identity)
                    await extensionContext.completeRegistrationRequest(using: response)
                } catch {
                    try? deletePasskey(credentialID: credentialID)
                    failed(error)
                }
            }
        } catch {
            try? deletePasskey(credentialID: credentialID)
            failed(error)
        }
    }
    
    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        logger.info("prepareInterface(forPasskeyRegistration:) called")
    }
    
    @IBAction func cancel(_ sender: AnyObject?) {
        logger.info(".cancel called")
        let error = NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue)
        self.extensionContext.cancelRequest(withError: error)
    }
}

enum CredentialProviderError: Error {
    case setItemFailed(OSStatus)
    case unexpectedPublicKeyFormat(UInt8)
    case publicKeyExtractionFailed
    case unexpectedCredentialRequest(ASCredentialRequest)
}

extension PasskeyEntry {
    init(_ identity: ASPasskeyCredentialIdentity) {
        self.relyingPartyIdentifier = identity.relyingPartyIdentifier
        self.userName = identity.userName
        self.userHandle = identity.userHandle
        self.signCount = 0
    }
}

func generateSecretKey(credentialID: Data) throws -> SecKey {
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

func storeToCredentialIdentityStore(credentialID: Data, identity: ASPasskeyCredentialIdentity) async throws {
    let passkeyIdentity = ASPasskeyCredentialIdentity(
        relyingPartyIdentifier: identity.relyingPartyIdentifier,
        userName: identity.userName,
        credentialID: credentialID,
        userHandle: identity.userHandle,
    )
    try await ASCredentialIdentityStore.shared.saveCredentialIdentities([passkeyIdentity])
}

func saveCredentialIdentity(credentialID: Data, identity: ASPasskeyCredentialIdentity) throws {
    let entry = PasskeyEntry(identity)
    let encoder = CodableCBOREncoder()
    let entryData = try encoder.encode(entry)
    
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecValueData: entryData,
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecAttrAccessGroup: group,
    ] as CFDictionary
    
    let status = SecItemAdd(query, nil)
    if status != errSecSuccess {
        throw CredentialProviderError.setItemFailed(status)
    }
}

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
    return ASPasskeyRegistrationCredential(
        relyingParty: identity.relyingPartyIdentifier,
        clientDataHash: clientDataHash,
        credentialID: credentialID,
        attestationObject: try encoder.encode(attestationObject)
    )
}

struct AuthenticatorData {
    struct CredentialData {
        static let aaguid = Data([
            0xec, 0x78, 0xfa, 0xe8, 0xb2, 0xe0, 0x56, 0x97,
            0x8e, 0x94, 0x7c, 0x77, 0x28, 0xc3, 0x95, 0x00
        ])
        let credentialID: Data
        let publicKey: SecKey
        
        private func encodePublicKey() throws -> [UInt8] {
            var error: Unmanaged<CFError>?
            guard let rawData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
                throw error!.takeRetainedValue()
            }
            
            // rawData: 04 || x (32bytes) || y (32bytes)
            let prefix = rawData[0]
            if prefix != 0x04 { throw CredentialProviderError.unexpectedPublicKeyFormat(prefix) }
            let x = rawData[1...32]
            let y = rawData[33...64]
            
            // COSE_Key: EC2, P-256, ES256
            let coseKey: CBOR = [
                1: 2,       // kty: EC2
                3: -7,      // alg: ES256
                -1: 1,      // crv: P-256
                -2: CBOR.byteString([UInt8](x)),  // x
                -3: CBOR.byteString([UInt8](y))   // y
            ]
            
            return coseKey.encode()
        }
        
        func encode() throws -> any Sequence<UInt8> {
            var credentialIDLength = UInt16(credentialID.count).bigEndian
            let credentialIDLengthData = Data(bytes: &credentialIDLength, count: MemoryLayout.size(ofValue: credentialIDLength))
            
            return [
                AnySequence(CredentialData.aaguid),
                AnySequence(credentialIDLengthData),
                AnySequence(credentialID),
                AnySequence(try encodePublicKey())
            ].joined()
        }
    }

    let relyingPartyIdentifier: String
    let signCount: UInt32
    let credentialData: CredentialData?

    func encode() throws -> Data {
        let rpIDHash = SHA256.hash(data: relyingPartyIdentifier.data(using: .utf8)!)
        
        let baseFlags: UInt8 = 0b00000101
        let flags: UInt8
        let encodedCredentialData: AnySequence<UInt8>
        if let credentialData {
            flags = baseFlags | 0b01000000
            encodedCredentialData = AnySequence(try credentialData.encode())
        } else {
            flags = baseFlags
            encodedCredentialData = AnySequence(EmptyCollection())
        }
        
        var signCount = self.signCount.bigEndian
        let signCountData = Data(bytes: &signCount, count: MemoryLayout.size(ofValue: signCount))
        
        let sequence = [
            AnySequence(rpIDHash),
            AnySequence(CollectionOfOne(flags)),
            AnySequence(signCountData),
            encodedCredentialData
        ].joined()
        
        return Data(sequence)
    }
}

struct AttestationObject: Encodable {
    let authData: Data
    let fmt = "none"
    let attStmt: [String: String] = [:]
    
    init(authData: AuthenticatorData) throws {
        self.authData = try authData.encode()
    }
    
    static func createForPasskeyRegistration(
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
