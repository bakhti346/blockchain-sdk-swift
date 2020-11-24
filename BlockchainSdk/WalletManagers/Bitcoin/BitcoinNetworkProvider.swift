//
//  BitcoinNetworkProvider.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 07.04.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import Combine

struct BtcFee {
    let minimalKb: Decimal
    let normalKb: Decimal
    let priorityKb: Decimal
}

struct BitcoinResponse {
    let balance: Decimal
    let hasUnconfirmed: Bool
    let txrefs: [BtcTx]
}

struct BtcTx {
    let tx_hash: String
    let tx_output_n: Int
    let value: UInt64
}

enum BitcoinNetworkApi {
    case main
	case blockchair
    case blockcypher
}

protocol BitcoinNetworkProvider {
    func getInfo(address: String) -> AnyPublisher<BitcoinResponse, Error>
    
    @available(iOS 13.0, *)
    func getFee() -> AnyPublisher<BtcFee, Error>
    
    @available(iOS 13.0, *)
    func send(transaction: String) -> AnyPublisher<String, Error>
}
