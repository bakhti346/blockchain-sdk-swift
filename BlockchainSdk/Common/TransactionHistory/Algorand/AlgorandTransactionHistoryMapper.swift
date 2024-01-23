//
//  AlgorandTransactionHistoryMapper.swift
//  BlockchainSdk
//
//  Created by skibinalexander on 22.01.2024.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk

struct AlgorandTransactionHistoryMapper {
    private let blockchain: Blockchain
    
    init(blockchain: Blockchain) {
        self.blockchain = blockchain
    }
}

extension AlgorandTransactionHistoryMapper {
    func mapToTransactionRecords(
        _ items: [AlgorandResponse.TransactionHistory.Item],
        amountType: Amount.AmountType,
        currentWalletAddress: String
    ) -> [TransactionRecord] {
        items.map {
            let decimalFeeValue = Decimal($0.fee) / blockchain.decimalValue
            let decimalAmountValue = Decimal($0.paymentTransaction.amount) / blockchain.decimalValue
            
            return TransactionRecord(
                hash: $0.id,
                source: .single(
                    .init(address: $0.sender, amount: decimalAmountValue)
                ),
                destination: .single(
                    .init(address: .user($0.paymentTransaction.receiver), amount: decimalAmountValue)
                ),
                fee: .init(.init(with: blockchain, value: decimalFeeValue)),
                status: .confirmed,
                isOutgoing: $0.sender.lowercased() == currentWalletAddress.lowercased() ,
                type: .transfer,
                date: $0.roundTime
            )
        }
    }
}
