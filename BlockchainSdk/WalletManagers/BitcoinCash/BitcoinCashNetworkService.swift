//
//  BitcoinCashNetworkService.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 14.02.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import Moya
import Combine
import TangemSdk

class BitcoinCashNetworkService {
    let provider = BlockchairProvider(endpoint: .bitcoinCash)

    func getInfo(address: String) -> AnyPublisher<BitcoinResponse, Error> {
        return provider.getInfo(address: address)
    }
    
    @available(iOS 13.0, *)
    func getFee() -> AnyPublisher<BtcFee, Error> {
        return provider.getFee()
    }
    
    @available(iOS 13.0, *)
    func send(transaction: String) -> AnyPublisher<String, Error> {
        return provider.send(transaction: transaction)
    }
}
