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

@available(iOS 13.0, *)
public class BitcoinCashAddressService: AddressService {
    internal static var addressPrefix: String { "bitcoincash" }
    
    public func makeAddress(from walletPublicKey: Data) throws -> String {
        let compressedKey = try Secp256k1Key(with: walletPublicKey).compress()
        let prefix = Data([UInt8(0x00)]) //public key hash
        let payload = RIPEMD160.hash(message: compressedKey.sha256())
        let walletAddress = HDWalletKit.Bech32.encode(prefix + payload, prefix: BitcoinCashAddressService.addressPrefix)
        return walletAddress
    }
    
    public func validate(_ address: String) -> Bool {
        return (try? BitcoinCashAddress(address)) != nil
    }
}
