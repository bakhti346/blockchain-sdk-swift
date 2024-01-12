//
//  AlgorandWalletManager.swift
//  BlockchainSdk
//
//  Created by skibinalexander on 09.01.2024.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation
import Combine

final class AlgorandWalletManager: BaseManager {
    
    // MARK: - Private Properties
    
    private let transactionBuilder: AlgorandTransactionBuilder
    private let networkService: AlgorandNetworkService
    
    /// The round for which this information is relevant.
    private var currentRoundBlock: UInt64 = 0
    
    // MARK: - Init
    
    init(wallet: Wallet, transactionBuilder: AlgorandTransactionBuilder, networkService: AlgorandNetworkService) throws {
        self.transactionBuilder = transactionBuilder
        self.networkService = networkService
        super.init(wallet: wallet)
    }
    
    // MARK: - Implementation
    
    override func update(completion: @escaping (Result<Void, Error>) -> Void) {
        cancellable = networkService
            .getAccount(address: wallet.address)
            .withWeakCaptureOf(self)
            .sink(
                receiveCompletion: { completionSubscription in
                    if case let .failure(error) = completionSubscription {
                        completion(.failure(error))
                    }
                },
                receiveValue: { walletManager, account in
                    walletManager.update(with: account, completion: completion)
                }
            )
    }
    
}

// MARK: - Private Implementation

private extension AlgorandWalletManager {
    func update(with accountModel: AlgorandResponse.Account, completion: @escaping (Result<Void, Error>) -> Void) {
        let blanaceValues = calculateCoinValueWithReserveDeposit(from: accountModel)
        
        wallet.add(coinValue: blanaceValues.coinValue)
        wallet.add(reserveValue: blanaceValues.reserveValue)
        
        if accountModel.amount < accountModel.minBalance {
            // TODO: - Сделать отображение ошибки no_account
        }
        
        currentRoundBlock = accountModel.round
        
        completion(.success(()))
        
//        switch accountModel.status {
//        case .Online, .Offline:
//            completion(.success(()))
//        case .NotParticipating:
//            let networkName = wallet.blockchain.displayName
//            let reserveValueString = blanaceValues.reserveValue.decimalNumber.stringValue
//            let currencySymbol = wallet.blockchain.currencySymbol
//            
//            completion(
//                .failure(
//                    WalletError.noAccount(
//                        message: "no_account_algorand".localized([networkName, reserveValueString, currencySymbol])
//                    )
//                )
//            )
//        }
    }
    
    private func calculateCoinValueWithReserveDeposit(from accountModel: AlgorandResponse.Account) -> (coinValue: Decimal, reserveValue: Decimal) {
        let changeBalanceValue = accountModel.amount > accountModel.minBalance ? accountModel.amount - accountModel.minBalance : 0
        
        let decimalBalance = Decimal(changeBalanceValue)
        let coinBalance = decimalBalance / wallet.blockchain.decimalValue
        
        let decimalReserveBalance = Decimal(accountModel.minBalance)
        let reserveCoinBalance = decimalReserveBalance / wallet.blockchain.decimalValue
        
        return (coinBalance, reserveCoinBalance)
    }
}

// MARK: - WalletManager protocol conformance

extension AlgorandWalletManager: WalletManager {
    var currentHost: String { networkService.host }

    var allowsFeeSelection: Bool { true }

    func getFee(amount: Amount, destination: String) -> AnyPublisher<[Fee], Error> {
        networkService
            .getTransactionParams()
            .withWeakCaptureOf(self)
            .map { walletManager, response in
                let sourceFee = Decimal(response.fee) / walletManager.wallet.blockchain.decimalValue
                let minFee = Decimal(response.minFee) / walletManager.wallet.blockchain.decimalValue
                
                let targetFee = sourceFee > minFee ? sourceFee : minFee
                
                return [Fee(.init(with: walletManager.wallet.blockchain, value: targetFee))]
            }
            .eraseToAnyPublisher()
    }

    func send(
        _ transaction: Transaction,
        signer: TransactionSigner
    ) -> AnyPublisher<TransactionSendResult, Error> {
        networkService
            .getTransactionParams()
            .withWeakCaptureOf(self)
            .map { walletManager, transactionInfoParams -> (AlgorandTransactionParams.Build) in
                let buildParams = AlgorandTransactionParams.Build(
                    publicKey: walletManager.wallet.publicKey,
                    genesisId: transactionInfoParams.genesisId,
                    genesisHash: transactionInfoParams.genesisHash,
                    round: walletManager.currentRoundBlock,
                    lastRound: transactionInfoParams.lastRound,
                    nonce: (transaction.params as? AlgorandTransactionParams.Input)?.nonce
                )
                
                return buildParams
            }
            .tryMap { buildParams -> (hash: Data, params: AlgorandTransactionParams.Build) in
                let hashForSign = try self.transactionBuilder.buildForSign(transaction: transaction, with: buildParams)
                return (hashForSign, buildParams)
            }
            .tryMap { transactionData -> (hash: Data, params: AlgorandTransactionParams.Build) in
                let hashForSend = try self.transactionBuilder.buildForSend(transaction: transaction, with: transactionData.params, signature: transactionData.hash)
                return (hashForSend, transactionData.params)
            }
            .flatMap { transactionData -> AnyPublisher<Data, Error> in
                return signer.sign(hash: transactionData.hash, walletPublicKey: transactionData.params.publicKey)
            }
            .withWeakCaptureOf(self)
            .flatMap { walletManager, transactionHash -> AnyPublisher<String, Error> in
                walletManager.networkService.sendTransaction(hash: transactionHash.hexString)
            }
            .map { outputHash in
                print(outputHash)
                return TransactionSendResult(hash: outputHash)
            }
            .eraseToAnyPublisher()
    }
}

/*
 Every account on Algorand must have a minimum balance of 100,000 microAlgos. If ever a transaction is sent that would result in a balance lower than the minimum, the transaction will fail. The minimum balance increases with each asset holding the account has (whether the asset was created or owned by the account) and with each application the account created or opted in. Destroying a created asset, opting out/closing out an owned asset, destroying a created app, or opting out an opted in app decreases accordingly the minimum balance.
 */
extension AlgorandWalletManager: MinimumBalanceRestrictable {
    var minimumBalance: Amount {
        let minimumBalanceAmountValue = (wallet.amounts[.reserve] ?? Amount(with: wallet.blockchain, value: 0)).value
        return Amount(with: wallet.blockchain, value: minimumBalanceAmountValue)
    }
}
