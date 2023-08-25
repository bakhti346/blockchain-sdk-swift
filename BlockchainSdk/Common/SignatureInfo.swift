//
//  SignatureInfo.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 29.06.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation

struct SignatureInfo: CustomStringConvertible {
    let signature: Data
    let publicKey: Data
    
    var description: String {
        "signature: \(signature.hex)\npublicKey: \(publicKey.hex)"
    }
}
