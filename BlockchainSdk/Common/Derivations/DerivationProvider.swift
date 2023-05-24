//
//  DerivationProvider.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 24.05.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk

public protocol DerivationProvider {
    func derivations(for blockchain: Blockchain) -> [AddressType: DerivationPath]
}
