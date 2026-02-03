//
//  CredentialProviderViewController.swift
//  CredentialProvider
//
//  Created by 村田紘司 on 2026/01/22.
//

import AuthenticationServices
import os
import SwiftCBOR
import LocalAuthentication
import SwiftUI

class CredentialProviderViewController: ASCredentialProviderViewController {
    private let viewModel = CredentialProviderViewModel()
    private var isCanceled = false

    override func loadView() {
        let hostingView = NSHostingView(rootView: CredentialProviderView(viewModel: viewModel, close: { [weak self] in
            guard let s = self else { return }
            let code = s.isCanceled ? ASExtensionError.userCanceled : ASExtensionError.failed
            s.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: code.rawValue))
        }))
        self.view = hostingView
    }
    
    private func failed(_ error: Error) {
        logger.error("failed: \(error)")
        viewModel.message = "\(error.localizedDescription)"
        viewModel.status = .failure
        if let error = error as? LAError, error.code == LAError.userCancel {
            isCanceled = true
        } else {
            isCanceled = false
        }
    }
    
    private func showNotSupported() {
        viewModel.message = "This feature is not supported. Please select a passkey from the system dialog."
        viewModel.status = .failure
        isCanceled = true
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        showNotSupported()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier], requestParameters: ASPasskeyCredentialRequestParameters) {
        showNotSupported()
    }

    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        guard let passkeyRequest = registrationRequest as? ASPasskeyCredentialRequest,
              let identity = passkeyRequest.credentialIdentity as? ASPasskeyCredentialIdentity
        else {
            failed(CredentialProviderError.unexpectedCredentialRequest(registrationRequest))
            return
        }
        
        let clientDataHash = passkeyRequest.clientDataHash
        Task.detached {
            let credentialID = Data((0..<16).map { _ in UInt8.random(in: 0...UInt8.max) })
            let entry = PasskeyEntry(identity)
            do {
                try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Register a passkey")

                let response = try createPasskeyRegistrationCredentialForPasskeyRegistration(
                    credentialID: credentialID, identity: identity, clientDataHash: clientDataHash
                )
                try saveCredentialIdentity(credentialID: credentialID, entry: entry)
                try await storeToCredentialIdentityStore(credentialID: credentialID, identity: identity)
                await MainActor.run {
                    self.extensionContext.completeRegistrationRequest(using: response)
                }
            } catch {
                try? deletePasskey(credentialID: credentialID)
                await MainActor.run { self.failed(error) }
            }
        }
    }
    
    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        extensionContext.cancelRequest(withError: NSError(
            domain: ASExtensionErrorDomain,
            code: ASExtensionError.userInteractionRequired.rawValue
        ))
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        guard let passkeyRequest = credentialRequest as? ASPasskeyCredentialRequest,
              let identity = passkeyRequest.credentialIdentity as? ASPasskeyCredentialIdentity
        else {
            failed(CredentialProviderError.unexpectedCredentialRequest(credentialRequest))
            return
        }

        let credentialID = identity.credentialID
        let clientDataHash = passkeyRequest.clientDataHash
        Task.detached {
            do {
                let response = try createPasskeyAssertionCredential(
                    credentialID: credentialID,
                    identity: identity,
                    clientDataHash: clientDataHash
                )
                await MainActor.run {
                    self.extensionContext.completeAssertionRequest(using: response)
                }
            } catch {
                await MainActor.run { self.failed(error) }
            }
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

func saveCredentialIdentity(credentialID: Data, entry: PasskeyEntry) throws {
    let encoder = CodableCBOREncoder()
    let entryData = try encoder.encode(entry)
    
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credentialID.base64EncodedString(),
        kSecValueData: entryData,
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecAttrAccessGroup: group,
        kSecUseDataProtectionKeychain: true,
    ] as CFDictionary
    
    let status = SecItemAdd(query, nil)
    if status != errSecSuccess {
        throw CredentialProviderError.setItemFailed(status)
    }
}
