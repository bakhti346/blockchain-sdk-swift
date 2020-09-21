//
//  WalletManagerFactory.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 06.12.2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk
import stellarsdk

public class WalletManagerFactory {
    public init() {}
        
    public func makeWalletManager(from card: Card) -> WalletManager? {
        guard let blockchainName = card.cardData?.blockchainName,
            let curve = card.curve,
            let blockchain = Blockchain.from(blockchainName: blockchainName, curve: curve),
            let walletPublicKey = card.walletPublicKey,
            let cardId = card.cardId else {
                return nil
        }
        
        let address = blockchain.makeAddress(from: walletPublicKey)
        let token = getToken(from: card, blockchain: blockchain)
        let wallet = Wallet(blockchain: blockchain, address: address, token: token)
        
        switch blockchain {
        case .bitcoin(let testnet):
            return BitcoinWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = BitcoinTransactionBuilder(walletAddress: address, walletPublicKey: walletPublicKey, isTestnet: testnet)
                $0.networkService = BitcoinNetworkService(address: address, isTestNet: testnet)
            }
            
        case .litecoin:
            return LitecoinWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = BitcoinTransactionBuilder(walletAddress: address, walletPublicKey: walletPublicKey, isTestnet: false)
                $0.networkService = LitecoinNetworkService(address: address, isTestNet: false)
            }
            
        case .ducatus:
            return BitcoinWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = BitcoinTransactionBuilder(walletAddress: address, walletPublicKey: walletPublicKey, isTestnet: false)
                $0.networkService = DucatusNetworkService(address: address)
            }
            
        case .stellar(let testnet):
            return StellarWalletManager(cardId: cardId, wallet: wallet).then {
                let url = testnet ? "https://horizon-testnet.stellar.org" : "https://horizon.stellar.org"
                let stellarSdk = StellarSDK(withHorizonUrl: url)
                $0.stellarSdk = stellarSdk
                $0.txBuilder = StellarTransactionBuilder(stellarSdk: stellarSdk, walletPublicKey: walletPublicKey, isTestnet: testnet)
                $0.networkService = StellarNetworkService(stellarSdk: stellarSdk, isAsset: token != nil)
            }
            
        case .ethereum(let testnet):
            let ethereumNetwork = testnet ? EthereumNetwork.testnet : EthereumNetwork.mainnet
            return EthereumWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = EthereumTransactionBuilder(walletPublicKey: walletPublicKey, network: ethereumNetwork)
                $0.networkService = EthereumNetworkService(network: ethereumNetwork, tokenDecimals: token?.decimalCount)
            }
            
        case .rsk:
            return EthereumWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = EthereumTransactionBuilder(walletPublicKey: walletPublicKey, network: .rsk)
                $0.networkService = EthereumNetworkService(network: .rsk, tokenDecimals: token?.decimalCount)
            }
            
        case .bitcoinCash(let testnet):
            return BitcoinCashWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = BitcoinCashTransactionBuilder(walletAddress: address, walletPublicKey: walletPublicKey, isTestnet: testnet)
                $0.networkService = BitcoinCashNetworkService(address: address)
            }
            
        case .binance(let testnet):
            return BinanceWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = BinanceTransactionBuilder(walletPublicKey: walletPublicKey, isTestnet: testnet)
                $0.networkService = BinanceNetworkService(address: address, assetCode: token?.contractAddress ,isTestNet: testnet)
            }
            
        case .cardano(let shelley):
            return CardanoWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = CardanoTransactionBuilder(walletPublicKey: walletPublicKey, shelleyCard: shelley)
                $0.networkService = CardanoNetworkService()
            }
            
        case .xrp(let curve):
            return XRPWalletManager(cardId: cardId, wallet: wallet).then {
                $0.txBuilder = XRPTransactionBuilder(walletPublicKey: walletPublicKey, curve: curve)
                $0.networkService = XRPNetworkService()
            }
        }
    }
    
    private func getToken(from card: Card, blockchain: Blockchain) -> Token? {
        if let symbol = card.cardData?.tokenSymbol,
            let contractAddress = card.cardData?.tokenContractAddress,
            let decimals = card.cardData?.tokenDecimal {
            
            var displayName: String
            switch blockchain {
            case .stellar:
                displayName = "Stellar Asset"
            case .ethereum:
                displayName = "Ethereum smart contract token"
            case .binance:
                displayName = "Binance Asset"
            case .rsk:
                displayName = blockchain.displayName
            default:
                fatalError("Unsupported blockchain")
            }
            
            return Token(currencySymbol: symbol, contractAddress: contractAddress, decimalCount: decimals, displayName: displayName)
        }
        return nil
    }
    
    public func isBlockchainSupported(_ card: Card) -> Bool {
        guard let blockchainName = card.cardData?.blockchainName,
            let curve = card.curve,
            let _ = Blockchain.from(blockchainName: blockchainName, curve: curve) else {
                return false
        }
        
        return true
    }
}
