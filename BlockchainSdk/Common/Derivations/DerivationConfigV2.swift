//
//  DerivationConfigV2.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 24.05.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation

/// Documentation:
/// Types:
/// - `Stellar`, `Solana`. According to `SEP0005`
/// https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0005.md
/// - `Cardano`.  According to  `CIP1852`
/// https://cips.cardano.org/cips/cip1852/
/// - `EVM-like` with `Ethereum` coinType(60).
/// - `All else`. According to `BIP44`
/// https://github.com/satoshilabs/slips/blob/master/slip-0044.md
public struct DerivationConfigV2: DerivationConfig {
    public func derivations(for blockchain: Blockchain) -> [AddressType: String] {
        switch blockchain {
        case .bitcoin:
            return [.legacy: "m/44'/0'/0'/0/0", .default: "m/44'/0'/0'/0/0"]
        case .litecoin:
            return [.legacy: "m/44'/2'/0'/0/0", .default: "m/44'/2'/0'/0/0"]
        case .stellar:
            return [.default: "m/44'/148'/0'"]
        case .solana:
            return [.default: "m/44'/501'/0'"]
        case .cardano(let shelley):
            // We use shelley for all new cards with HD wallets feature.
            guard shelley else {
                return [:]
            }
            return [.legacy: "m/1852'/1815'/0'/0/0", .default: "m/1852'/1815'/0'/0/0"]
        case .bitcoinCash:
            return [.legacy: "m/44'/145'/0'/0/0", .default: "m/44'/145'/0'/0/0"]
        case .ethereum,
                .ethereumPoW,
                .ethereumFair,
                .saltPay,
                .ethereumClassic,
                .rsk,
                .bsc,
                .polygon,
                .avalanche,
                .fantom,
                .arbitrum,
                .gnosis,
                .optimism,
                .kava,
                .cronos:
            return [.default: "m/44'/60'/0'/0/0"]
        case .binance:
            return [.default: "m/44'/714'/0'/0/0"]
        case .xrp:
            return [.default: "m/44'/144'/0'/0/0"]
        case .tezos:
            return [.default: "m/44'/1729'/0'/0/0"]
        case .dogecoin:
            return [.default: "m/44'/3'/0'/0/0"]
        case .polkadot:
            return [.default: "m/44'/354'/0'/0/0"]
        case .kusama:
            return [.default: "m/44'/434'/0'/0/0"]
        case .azero:
            return [.default: "m/44'/643'/0'/0'/0'"]
        case .tron:
            return [.default: "m/44'/195'/0'/0/0"]
        case .dash:
            return [.default: "m/44'/5'/0'/0/0"]
        case .ton:
            return [.default: "m/44'/607'/0'/0/0"]
        case .kaspa:
            return [.default: "m/44'/111111'/0'/0/0"]
        case .ravencoin:
            return [.default: "m/44'/175'/0'/0/0"]
        case .cosmos:
            return [.default: "m/44'/118'/0'/0/0"]
        case .terraV1, .terraV2:
            return [.default: "m/44'/330'/0'/0/0"]
        }
    }
}
