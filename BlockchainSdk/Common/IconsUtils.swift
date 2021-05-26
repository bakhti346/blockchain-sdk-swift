//
//  IconsUtils.swift
//  BlockchainSdk
//
//  Created by Andrew Son on 22/04/21.
//  Copyright © 2021 Tangem AG. All rights reserved.
//

import Foundation
import web3swift

public enum IconsUtils {
    private static var baseUrl: String {
        "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains"
    }
    private static var logoSuffix: String { "logo.png" }
    
    public static func getBlockchainIconUrl(_ blockchain: Blockchain) -> URL? {
        guard let blockchainPath = blockchain.getPath else { return nil }
        
        return URL(string: baseUrl)?
            .appendingPathComponent(blockchainPath)
            .appendingPathComponent("info")
            .appendingPathComponent(logoSuffix)
    }
    
    public static func getTokenIconUrl(for blockchain: Blockchain, token: Token) -> URL? {
        guard
            blockchain.tokenIconsAvailable,
            let blockchainPath = blockchain.getPath
        else { return nil }
        
        let tokenPath = normalizeAssetPath(token.contractAddress, blockchain: blockchain)
        return URL(string: baseUrl)?
            .appendingPathComponent(blockchainPath)
            .appendingPathComponent("assets")
            .appendingPathComponent(tokenPath)
            .appendingPathComponent(logoSuffix)
    }
    
    private static func normalizeAssetPath(_ path: String, blockchain: Blockchain) -> String {
        switch blockchain {
        case .ethereum:
            return EthereumAddress.toChecksumAddress(path) ?? path
        case .binance:
            return path.uppercased()
        default:
            return path
        }
    }
}

fileprivate extension Blockchain {
    var getPath: String? {
        switch self {
        case .bitcoin:
            return "bitcoin"
        case .litecoin:
            return "litecoin"
        case .stellar:
            return "stellar"
        case .ethereum:
            return "ethereum"
        case .bitcoinCash:
            return "bitcoincash"
        case .binance:
            return "binance"
        case .cardano:
            return "cardano"
        case .xrp:
            return "xrp"
        case .tezos:
            return "tezos"
        case .rsk, .ducatus:
            return nil
        case .bsc:
            return "smartchain"
        }
    }
    
    var tokenIconsAvailable: Bool {
        switch self {
        case .ethereum, .binance:
            return true
        default:
            return false
        }
    }
}
