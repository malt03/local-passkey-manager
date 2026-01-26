//
//  AttestationObject.swift
//  LocalPasskeyManager
//
//  Created by 村田紘司 on 2026/01/24.
//

import Foundation
import SwiftCBOR
import CryptoKit
import os

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
        
        fileprivate func encode() throws -> any Sequence<UInt8> {
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

    private let relyingPartyIdentifier: String
    private let signCount: UInt32
    private let credentialData: CredentialData?
    
    init(relyingPartyIdentifier: String, signCount: UInt32, credentialData: CredentialData?) {
        self.relyingPartyIdentifier = relyingPartyIdentifier
        self.signCount = signCount
        self.credentialData = credentialData
    }

    func encode() throws -> Data {
        let rpIDHash = SHA256.hash(data: relyingPartyIdentifier.data(using: .utf8)!)
        
        // UP (User Present): bit 0
        // UV (User Verified): bit 2
        // BE (Backup Eligible): bit 3
        // BS (Backup State): bit 4
        // Note: BE and BS should be 0 for device-bound credentials,
        //       but Apple's Credential Provider Extension requires them to be 1.
        //       See: https://developer.apple.com/forums/thread/813844
        let baseFlags: UInt8 = 0b00011101
        let flags: UInt8
        let encodedCredentialData: AnySequence<UInt8>
        if let credentialData {
            // AT (Attested Credential Data present): bit 6
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
}
