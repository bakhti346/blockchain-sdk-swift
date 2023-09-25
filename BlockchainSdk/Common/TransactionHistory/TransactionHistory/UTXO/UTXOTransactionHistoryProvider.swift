//
//  UTXOTransactionHistoryProvider.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 26.07.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import Combine

class UTXOTransactionHistoryProvider: MultiNetworkProvider {
    var currentProviderIndex: Int = 0
    var providers: [BlockBookUtxoProvider] {
        blockBookProviders
    }

    private let blockBookProviders: [BlockBookUtxoProvider]
    private let mapper: BlockBookTransactionHistoryMapper

    init(
        blockBookProviders: [BlockBookUtxoProvider],
        mapper: BlockBookTransactionHistoryMapper
    ) {
        self.blockBookProviders = blockBookProviders
        self.mapper = mapper
    }
}

extension UTXOTransactionHistoryProvider: TransactionHistoryProvider {
    func loadTransactionHistory(request: TransactionHistory.Request) -> AnyPublisher<TransactionHistory.Response, Error> {
        providerPublisher { [weak self] provider in
            guard let self else {
                return .anyFail(error: WalletError.empty)
            }
            
            let parameters = BlockBookTarget.AddressRequestParameters(
                page: request.page.number,
                pageSize: request.page.size,
                details: [.txslight]
            )
            
            return provider.addressData(address: request.address, parameters: parameters)
                .tryMap { [weak self] response -> TransactionHistory.Response in
                    guard let self else {
                        throw WalletError.empty
                    }
                    
                    let records = self.mapper.mapToTransactionRecords(response, amountType: .coin)
                    return TransactionHistory.Response(
                        totalPages: response.totalPages ?? 0,
                        totalRecordsCount: response.txs,
                        page: Page(number: response.page ?? 0, size: response.itemsOnPage ?? 0),
                        records: records
                    )
                }
                .eraseToAnyPublisher()
        }
    }
}