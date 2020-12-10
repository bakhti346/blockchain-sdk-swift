//
//  Blockchain.swift
//  blockchainSdk
//
//  Created by Alexander Osokin on 04.12.2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk
import BitcoinCore

public enum Blockchain {
    case bitcoin(testnet: Bool)
    case litecoin
    case stellar(testnet: Bool)
    case ethereum(testnet: Bool)
    case rsk
    case bitcoinCash(testnet: Bool)
    case binance(testnet: Bool)
    case cardano(shelley: Bool)
    case xrp(curve: EllipticCurve)
    case ducatus
    case tezos
    
    public var isTestnet: Bool {
        switch self {
        case .bitcoin(let testnet):
            return testnet
        case .litecoin, .ducatus, .cardano, .xrp, .rsk, .tezos:
            return false
        case .stellar(let testnet):
            return testnet
        case .ethereum(let testnet):
            return testnet
        case .bitcoinCash(let testnet):
            return testnet
        case .binance(let testnet):
            return testnet
        }
    }
    
    public var decimalCount: Int {
        switch self {
        case .bitcoin, .litecoin, .bitcoinCash, .ducatus, .binance:
            return 8
        case .ethereum, .rsk:
            return 18
        case  .cardano, .xrp, .tezos:
            return 6
        case .stellar:
            return 7
        }
    }
    
    public var decimalValue: Decimal {
        return pow(Decimal(10), decimalCount)
    }
    
    public var roundingMode: NSDecimalNumber.RoundingMode {
        switch self {
        case .bitcoin, .litecoin, .ethereum, .rsk, .bitcoinCash, .binance, .ducatus:
            return .down
        case .stellar, .xrp, .tezos:
            return .plain
        case .cardano:
            return .up
        }
    }
    public var currencySymbol: String {
        switch self {
        case .bitcoin:
            return "BTC"
        case .litecoin:
            return "LTC"
        case .stellar:
            return "XLM"
        case .ethereum:
            return "ETH"
        case .rsk:
            return "RBTC"
        case .bitcoinCash:
            return "BCH"
        case .binance:
            return "BNB"
        case .ducatus:
            return "DUC"
        case .cardano:
            return "ADA"
        case .xrp:
            return "XRP"
        case .tezos:
            return "XTZ"
        }
    }
    
    public var displayName: String {
        switch self {
        case .bitcoinCash:
            return "Bitcoin Cash"
        case .xrp:
            return "XRP Ledger"
        case .rsk:
            return "\(self)".uppercased()
        default:
            var name = "\(self)".capitalizingFirstLetter()
            if let index = name.firstIndex(of: "(") {
                name = String(name.prefix(upTo: index))
            }
            return isTestnet ?  name + " test" : name
        }
    }
    
    public var tokenDisplayName: String {
        switch self {
        case .stellar:
            return "Stellar Asset"
        case .ethereum:
            return "Ethereum smart contract token"
        case .binance:
            return "Binance Asset"
        default:
            return displayName
        }
    }
    
    public var qrPrefix: String {
        switch self {
        case .bitcoin:
            return "bitcoin:"
        case .ethereum(let testnet):
            return testnet ? "" : "ethereum:"
        case .litecoin:
            return "litecoin:"
        case .xrp:
            return "xrpl:"
        case .binance:
            return "bnb:"
        default:
            return ""
        }
    }
	
	public var defaultAddressType: AddressType {
		switch self {
		case .bitcoin: return .bitcoin(type: .bech32)
		default: return .plain
		}
	}
    
    public func makeAddresses(from walletPublicKey: Data) -> [Address] {
        return getAddressService().makeAddresses(from: walletPublicKey)
    }
	
	public func makeMultisigAddresses(from walletPublicKey: Data, with pairPublicKey: Data) -> [Address]? {
		guard let service = getAddressService() as? MultisigAddressProvider else { return nil }
		return service.makeAddresses(from: walletPublicKey, with: pairPublicKey)
	}
    
    public func validate(address: String) -> Bool {
        switch self {
        case .cardano:
            return CardanoAddress.validate(address)
        default:
            return getAddressService().validate(address)
        }
    }
    
    public func getShareString(from address: String) -> String {
        switch self {
        case .bitcoin:
            return "\(qrPrefix)\(address)"
        case .ethereum:
            return "\(qrPrefix)\(address)"
        case .litecoin:
            return "\(qrPrefix)\(address)"
        case .xrp:
            return "\(qrPrefix)\(address)"
        default:
            return "\(address)"
        }
    }
    
    public func getExploreURL(from address: String, tokenContractAddress: String? = nil) -> URL {
        switch self {
        case .binance:
            return URL(string: "https://explorer.binance.org/address/\(address)")!
        case .bitcoin:
            return URL(string: "https://blockchain.info/address/\(address)")!
        case .bitcoinCash:
            return URL(string: "https://blockchair.com/bitcoin-cash/address/\(address)")!
        case .cardano:
            return URL(string: "https://cardanoexplorer.com/address/\(address)")!
        case .ducatus:
            return URL(string: "https://insight.ducatus.io/#/DUC/mainnet/address/\(address)")!
        case .ethereum(let testnet):
            let baseUrl = testnet ? "https://rinkeby.etherscan.io/address/" : "https://etherscan.io/address/"
            let exploreLink = tokenContractAddress == nil ? baseUrl + address :
            "https://etherscan.io/token/\(tokenContractAddress!)?a=\(address)"
            return URL(string: exploreLink)!
        case .litecoin:
            return URL(string: "https://live.blockcypher.com/ltc/address/\(address)")!
        case .rsk:
            var exploreLink = "https://explorer.rsk.co/address/\(address)"
            if tokenContractAddress != nil {
                exploreLink += "?__tab=tokens"
            }
            return URL(string: exploreLink)!
        case .stellar(let testnet):
            let baseUrl = testnet ? "https://stellar.expert/explorer/testnet/account/" : "https://stellar.expert/explorer/public/account/"
            let exploreLink =  baseUrl + address
            return URL(string: exploreLink)!
        case .xrp:
            return URL(string: "https://xrpscan.com/account/\(address)")!
        case .tezos:
            return URL(string: "https://tezblock.io/account/\(address)")!
        }
    }
    
    public static func from(blockchainName: String, curve: EllipticCurve) -> Blockchain? {
        let testnetAttribute = "/test"
        let isTestnet = blockchainName.contains(testnetAttribute)
        let cleanName = blockchainName.remove(testnetAttribute).lowercased()
        switch cleanName {
        case "btc": return .bitcoin(testnet: isTestnet)
        case "xlm", "asset", "xlm-tag": return .stellar(testnet: isTestnet)
        case "eth", "token", "nfttoken": return .ethereum(testnet: isTestnet)
        case "ltc": return .litecoin
        case "rsk", "rsktoken": return .rsk
        case "bch": return .bitcoinCash(testnet: isTestnet)
        case "binance", "binanceasset": return .binance(testnet: isTestnet)
        case "cardano": return .cardano(shelley: false)
        case "cardano-s": return .cardano(shelley: true)
        case "xrp": return .xrp(curve: curve)
        case "duc": return .ducatus
        case "xtz": return .tezos
        default: return nil
        }
    }
    
    func getAddressService() -> AddressService {
        switch self {
        case .bitcoin(let testnet):
            let network: BitcoinNetwork = testnet ? .testnet : .mainnet
            let networkParams = network.networkParams
            return BitcoinAddressService(networkParams: networkParams)
        case .litecoin:
            return BitcoinLegacyAddressService(networkParams: LitecoinNetworkParams())
        case .stellar:
            return StellarAddressService()
        case .ethereum, .rsk:
            return EthereumAddressService()
        case .bitcoinCash:
            return BitcoinCashAddressService()
        case .binance(let testnet):
            return BinanceAddressService(testnet: testnet)
        case .ducatus:
            return BitcoinLegacyAddressService(networkParams: DucatusNetworkParams())
        case .cardano(let shelley):
            return shelley ? CardanoShelleyAddressService() : CardanoAddressService()
        case .xrp(let curve):
            return XRPAddressService(curve: curve)
        case .tezos:
            return TezosAddressService()
        }
    }
}
