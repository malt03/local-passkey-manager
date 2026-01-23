//
//  CredentialProviderViewController.swift
//  CredentialProvider
//
//  Created by 村田紘司 on 2026/01/22.
//

import AuthenticationServices
import os
import SwiftCBOR

private let logger = Logger(subsystem: "com.malt03.LocalPasskeyManager", category: "CredentialProvider")

class CredentialProviderViewController: ASCredentialProviderViewController {
    @IBOutlet var errorLabel: NSTextField!
    
    private var error: Error?

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("viewDidLoad")
    }
    
    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        func failed(_ error: Error) {
            errorLabel.stringValue = "Failed: \(error)"
            self.error = error
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
        
        if self.error == nil {
            extensionContext.cancelRequest(
                withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue)
            )
        } else {
            extensionContext.cancelRequest(
                withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
            )
        }
    }
}

extension PasskeyEntry {
    init(_ identity: ASPasskeyCredentialIdentity) {
        self.relyingPartyIdentifier = identity.relyingPartyIdentifier
        self.userName = identity.userName
        self.userHandle = identity.userHandle
        self.signCount = 0
    }
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
