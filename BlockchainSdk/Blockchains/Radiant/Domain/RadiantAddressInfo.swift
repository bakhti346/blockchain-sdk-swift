//
//  RadiantAddressInfo.swift
//  BlockchainSdk
//
//  Created by skibinalexander on 19.03.2024.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation

struct RadiantAddressInfo {
    let balance: Decimal
    let outputs: [RadiantUTXO]
}

// TODO: - Need remove after merge https://github.com/tangem/blockchain-sdk-swift/pull/603
struct RadiantUTXO {
    let position: Int
    let hash: String
    let value: Decimal
    let height: Decimal
}
