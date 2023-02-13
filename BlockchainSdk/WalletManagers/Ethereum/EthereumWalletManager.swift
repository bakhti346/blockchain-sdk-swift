//
//  EthereumWalletManager.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 13.12.2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation
import BigInt
import Combine
import TangemSdk
import Moya
import web3swift

public enum ETHError: Error, LocalizedError, DetailedError {
    case failedToParseTxCount
    case failedToParseBalance(value: String, address: String, decimals: Int)
    case failedToParseGasLimit
    case unsupportedFeature
    
    public var errorDescription: String? {
        switch self {
        case .failedToParseTxCount:
            return "eth_tx_count_parse_error".localized
        case .failedToParseBalance:
            return "eth_balance_parse_error".localized
        case .failedToParseGasLimit: //TODO: refactor
            return "failedToParseGasLimit"
        case .unsupportedFeature:
            return "unsupportedFeature"
        }
    }
    
    public var detailedDescription: String? {
        switch self {
        case .failedToParseBalance(let value, let address, let decimals):
            return "value:\(value), address:\(address), decimals:\(decimals)"
        default:
            return nil
        }
    }
}

@available(iOS 13.0, *)
public protocol EthereumGasLoader: AnyObject {
    func getGasPrice() -> AnyPublisher<BigUInt, Error>
    func getGasLimit(to: String, from: String, value: String?, data: String?) -> AnyPublisher<BigUInt, Error>
}

public protocol EthereumTransactionSigner: AnyObject {
    func sign(_ transaction: Transaction, signer: TransactionSigner) -> AnyPublisher<String, Error>
}

public protocol EthereumTransactionProcessor {
    var initialNonce: Int { get }
    func buildForSign(_ transaction: Transaction) -> AnyPublisher<CompiledEthereumTransaction, Error>
    func buildForSend(_ transaction: SignedEthereumTransaction) -> AnyPublisher<String, Error>
    func getFee(to: String, data: String?, amount: Amount?) -> AnyPublisher<[Amount], Error>
    func send(_ transaction: SignedEthereumTransaction) -> AnyPublisher<String, Error>
    func getAllowance(from: String, to: String, contractAddress: String) -> AnyPublisher<String, Error>
}

public struct CompiledEthereumTransaction {
    public let transaction: EthereumTransaction
    public let hash: Data
}

public struct SignedEthereumTransaction {
    public let transaction: EthereumTransaction
    public let hash: Data
    public let signature: Data
    
    public init(compiledTransaction: CompiledEthereumTransaction, signature: Data) {
        self.transaction = compiledTransaction.transaction
        self.hash = compiledTransaction.hash
        self.signature = signature
    }
}

class EthereumWalletManager: BaseManager, WalletManager, EthereumTransactionSigner {
    var txBuilder: EthereumTransactionBuilder!
    var networkService: EthereumNetworkService!
    
    var txCount: Int = -1
    var pendingTxCount: Int = -1
    
    var currentHost: String { networkService.host }
    
    private var gasLimit: BigUInt? = nil
    private var findTokensSubscription: AnyCancellable? = nil
    
    func update(completion: @escaping (Result<Void, Error>)-> Void) {
        cancellable = networkService
            .getInfo(address: wallet.address, tokens: cardTokens)
            .sink(receiveCompletion: {[unowned self] completionSubscription in
                if case let .failure(error) = completionSubscription {
                    self.wallet.amounts = [:]
                    completion(.failure(error))
                }
            }, receiveValue: { [unowned self] response in
                self.updateWallet(with: response)
                completion(.success(()))
            })
    }
    
    func getFee(amount: Amount, destination: String) -> AnyPublisher<[Amount],Error> {
        let destinationInfo = formatDestinationInfo(for: destination, amount: amount)
        return getFee(to: destinationInfo.to, value: destinationInfo.value, data: destinationInfo.data)
    }
    
    private func getFee(to: String, value: String?, data: String?) -> AnyPublisher<[Amount], Error> {
        return networkService.getFee(to: to,
                                     from: wallet.address,
                                     value: value,
                                     data: data)
        .tryMap {
            guard $0.fees.count == 3 else {
                throw BlockchainSdkError.failedToLoadFee
            }
            self.gasLimit = $0.gasLimit
            
            let minAmount = Amount(with: self.wallet.blockchain, value: $0.fees[0])
            let normalAmount = Amount(with: self.wallet.blockchain, value: $0.fees[1])
            let maxAmount = Amount(with: self.wallet.blockchain, value: $0.fees[2])
            let feeArray = [minAmount, normalAmount, maxAmount]
            print("Fee: \(feeArray)")
            return feeArray
        }
        .eraseToAnyPublisher()
    }
    
    func sign(_ transaction: Transaction, signer: TransactionSigner) -> AnyPublisher<String, Error> {
        guard let txForSign = txBuilder.buildForSign(transaction: transaction,
                                                     nonce: txCount,
                                                     gasLimit: gasLimit) else {
            return Fail(error: WalletError.failedToBuildTx).eraseToAnyPublisher()
        }
        
        return signer.sign(hash: txForSign.hash,
                           walletPublicKey: self.wallet.publicKey)
        .tryMap {[weak self] signature -> String in
            guard let self = self else { throw WalletError.empty }
            
            guard let tx = self.txBuilder.buildForSend(transaction: txForSign.transaction, hash: txForSign.hash, signature: signature) else {
                throw WalletError.failedToBuildTx
            }
            
            return "0x\(tx.toHexString())"
        }
        .eraseToAnyPublisher()
    }
    
    private func updateWallet(with response: EthereumInfoResponse) {
        wallet.add(coinValue: response.balance)
        for tokenBalance in response.tokenBalances {
            wallet.add(tokenValue: tokenBalance.value, for: tokenBalance.key)
        }
       
        txCount = response.txCount
        pendingTxCount = response.pendingTxCount
        
        if !response.pendingTxs.isEmpty {
            wallet.transactions.removeAll()
            response.pendingTxs.forEach {
                wallet.addPendingTransaction($0)
            }
        } else if txCount == pendingTxCount {
            for  index in wallet.transactions.indices {
                wallet.transactions[index].status = .confirmed
            }
        } else {
            if wallet.transactions.isEmpty {
                wallet.addDummyPendingTransaction()
            }
        }
    }
    
    private func formatDestinationInfo(for destination: String, amount: Amount) -> (to: String, value: String?, data: String?) {
        var to = destination
        var value: String? = nil
        var data: String? = nil
        
        if amount.type == .coin {
            value = amount.encodedForSend
        }
        
        if let token = amount.type.token, let erc20Data = txBuilder.getData(for: amount, targetAddress: destination) {
            to = token.contractAddress
            data = erc20Data.hexString.addHexPrefix()
        }
        
        return (to, value, data)
    }
}

extension EthereumWalletManager: TransactionSender {
    var allowsFeeSelection: Bool { true }
    
    func send(_ transaction: Transaction, signer: TransactionSigner) -> AnyPublisher<TransactionSendResult, Error> {
        sign(transaction, signer: signer)
            .flatMap {[weak self] tx -> AnyPublisher<TransactionSendResult, Error> in
                self?.networkService.send(transaction: tx).tryMap {[weak self] sendResponse in
                    guard let self = self else { throw WalletError.empty }
                    
                    var tx = transaction
                    tx.hash = sendResponse
                    self.wallet.add(transaction: tx)
                    return TransactionSendResult(hash: sendResponse)
                }
                .mapError { SendTxError(error: $0, tx: tx) }
                .eraseToAnyPublisher() ?? .emptyFail
            }
            .eraseToAnyPublisher()
    }
}

extension EthereumWalletManager: EthereumGasLoader {
    func getGasPrice() -> AnyPublisher<BigUInt, Error> {
        networkService.getGasPrice()
    }
    
    func getGasLimit(to: String, from: String, value: String?, data: String?) -> AnyPublisher<BigUInt, Error> {
        return networkService
            .getGasLimit(to: to, from: from, value: value, data: data)
            .eraseToAnyPublisher()
    }
}

extension EthereumWalletManager: SignatureCountValidator {
    func validateSignatureCount(signedHashes: Int) -> AnyPublisher<Void, Error> {
        networkService.getSignatureCount(address: wallet.address)
            .tryMap {
                if signedHashes != $0 { throw BlockchainSdkError.signatureCountNotMatched }
            }
            .eraseToAnyPublisher()
    }
}

extension EthereumWalletManager: ThenProcessable { }

extension EthereumWalletManager: TokenFinder {
    func findErc20Tokens(knownTokens: [Token], completion: @escaping (Result<Bool, Error>)-> Void) {
        findTokensSubscription?.cancel()
        findTokensSubscription = networkService
            .findErc20Tokens(address: wallet.address)
            .sink(receiveCompletion: { subscriptionCompletion in
                if case let .failure(error) = subscriptionCompletion {
                    completion(.failure(error))
                    return
                }
            }, receiveValue: {[unowned self] blockchairTokens in
                if blockchairTokens.isEmpty {
                    completion(.success(false))
                    return
                }
                
                var tokensAdded = false
                blockchairTokens.forEach { blockchairToken in
                    let foundToken = Token(blockchairToken, blockchain: self.wallet.blockchain)
                    if !self.cardTokens.contains(foundToken) {
                        let token: Token = knownTokens.first(where: { $0 == foundToken }) ?? foundToken
                        self.cardTokens.append(token)
                        let balanceValue = Decimal(blockchairToken.balance) ?? 0
                        let balanceWeiValue = balanceValue / pow(Decimal(10), blockchairToken.decimals)
                        self.wallet.add(tokenValue: balanceWeiValue, for: token)
                        tokensAdded = true
                    }
                }
                
                completion(.success(tokensAdded))
            })
    }
}

extension EthereumWalletManager: EthereumTransactionProcessor {
    var initialNonce: Int {
        self.txCount
    }
    
    func buildForSign(_ transaction: Transaction) -> AnyPublisher<CompiledEthereumTransaction, Error> {
        guard let txForSign = txBuilder.buildForSign(transaction: transaction,
                                                     nonce: txCount,
                                                     gasLimit: gasLimit) else {
            return .anyFail(error: WalletError.failedToBuildTx)
        }
        
        let compiled = CompiledEthereumTransaction(transaction: txForSign.transaction, hash: txForSign.hash)
        return .justWithError(output: compiled)
    }
    
    func buildForSend(_ transaction: SignedEthereumTransaction) -> AnyPublisher<String, Error> {
        guard let tx = txBuilder.buildForSend(transaction: transaction.transaction,
                                              hash: transaction.hash,
                                              signature: transaction.signature) else {
            return .anyFail(error: WalletError.failedToBuildTx)
        }
        
        return .justWithError(output: "0x\(tx.toHexString())")
    }
    
    func getFee(to: String, data: String?, amount: Amount?) -> AnyPublisher<[Amount], Error> {
        getFee(to: to, value: amount?.encodedForSend, data: data)
    }
    
    func send(_ transaction: SignedEthereumTransaction) -> AnyPublisher<String, Error> {
        buildForSend(transaction)
            .flatMap {[weak self] serializedTransaction -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return .anyFail(error: WalletError.empty)
                }
                
                return self.networkService
                    .send(transaction: serializedTransaction)
                    .mapError { SendTxError(error: $0, tx: serializedTransaction) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    func getAllowance(from: String, to: String, contractAddress: String) -> AnyPublisher<String, Error> {
        networkService.getAllowance(from: from, to: to, contractAddress: contractAddress)
    }
}

extension EthereumWalletManager: TransactionHistoryLoader {
    func loadTransactionHistory(address: String, blockchain: Blockchain, amountType: Amount.AmountType) -> AnyPublisher<[Transaction], Error> {
        networkService.loadTransactionHistory(for: address)
            .map { [weak self] (blockscoutTransctions: [BlockscoutTransaction]) -> [Transaction] in
                guard let self else { return [] }
                
                let token: Token? = amountType.token
                let decimalCount: Int = token?.decimalCount ?? blockchain.decimalCount
                let currencySymbol: String = token?.symbol ?? blockchain.currencySymbol
                
                let transactions: [Transaction] = blockscoutTransctions.compactMap {
                    guard
                        let amountDecimal = Decimal($0.value),
                        let gasPriceDecimal = Decimal($0.gasPrice),
                        let spentGas = Decimal($0.gasUsed)
                    else { return nil }
                    
                    switch amountType {
                    case .coin:
                        guard $0.contractAddress.isEmpty else {
                            return nil
                        }
                    case .token(let token):
                        guard $0.contractAddress == token.contractAddress else {
                            return nil
                        }
                        break
                    case .reserve:
                        return nil
                    }
                    
                    let timestamp = TimeInterval($0.timeStamp) ?? Date().timeIntervalSince1970
                    let date = Date(timeIntervalSince1970: timestamp)
                    let confirmationsCount = Int($0.confirmations) ?? 0
                    let amount = Amount(
                        type: amountType,
                        currencySymbol: currencySymbol,
                        value: amountDecimal / pow(10, decimalCount),
                        decimals: decimalCount
                    )
                    let fee = Amount(
                        type: amountType,
                        currencySymbol: blockchain.currencySymbol,
                        value: (gasPriceDecimal * spentGas) / pow(10, decimalCount),
                        decimals: blockchain.decimalCount
                    )
                    
                    return Transaction(
                        amount: amount,
                        fee: fee,
                        sourceAddress: $0.from,
                        destinationAddress: $0.to,
                        changeAddress: .unknown,
                        date: date,
                        status: confirmationsCount > 0 ? .confirmed : .unconfirmed,
                        hash: $0.hash
                    )
                }
                
                self.wallet.setTransactionHistoryList(transactions)
                return transactions
            }
            .eraseToAnyPublisher()
    }
}
