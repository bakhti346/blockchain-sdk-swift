//
//  BitcoinCashAddressService.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 14.02.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import HDWalletKit
import TangemSdk
import BitcoinCore

@available(iOS 13.0, *)
public class BitcoinCashAddressService {
    private let legacyService: BitcoinLegacyAddressService
    private let bitcoinCashAddressService: DefaultBitcoinCashAddressService
    
    public init(networkParams: INetwork) {
        self.legacyService = .init(networkParams: networkParams)
        self.bitcoinCashAddressService = .init(networkParams: networkParams)
    }
}

// MARK: - AddressValidator

@available(iOS 13.0, *)
extension BitcoinCashAddressService: AddressValidator {
    public func validate(_ address: String) -> Bool {
        bitcoinCashAddressService.validate(address) || legacyService.validate(address)
    }
}

// MARK: - AddressProvider

@available(iOS 13.0, *)
extension BitcoinCashAddressService: AddressProvider {
    public func makeAddress(for publicKey: Wallet.PublicKey, with addressType: AddressType) throws -> AddressPublicKeyPair {
        switch addressType {
        case .default:
            let address = try bitcoinCashAddressService.makeAddress(from: publicKey.blockchainKey)
            return AddressPublicKeyPair(value: address, publicKey: publicKey, type: addressType)
        case .legacy:
            let compressedKey = try Secp256k1Key(with: publicKey.blockchainKey).compress()
            let address = try legacyService.makeAddress(from: compressedKey).value
            return AddressPublicKeyPair(value: address, publicKey: publicKey, type: addressType)
        }
    }
}

// MARK: - MultipleAddressProvider

@available(iOS 13.0, *)
extension BitcoinCashAddressService: MultipleAddressProvider {
    public func makeAddresses(from walletPublicKey: Data) throws -> [Address] {
        let address = try bitcoinCashAddressService.makeAddress(from: walletPublicKey)
        let compressedKey = try Secp256k1Key(with: walletPublicKey).compress()
        let legacyString = try legacyService.makeAddress(from: compressedKey).value

        let cashAddress = PlainAddress(value: address, type: .default)
        let legacy = PlainAddress(value: legacyString, type: .legacy)

        return [cashAddress, legacy]
    }
}
