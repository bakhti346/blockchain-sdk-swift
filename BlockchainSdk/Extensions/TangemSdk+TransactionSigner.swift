//
//  CardManager.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 17.12.2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk
import Combine

@available(iOS 13.0, *)
public class CommonSigner {
    public var initialMessage: Message?
    public var cardId: String?
    
    private let sdk: TangemSdk
    
    public init(sdk: TangemSdk, initialMessage: Message? = nil, cardId: String? = nil) {
        self.sdk = sdk
        self.initialMessage = initialMessage
        self.cardId = cardId
    }
}

extension CommonSigner: TransactionSigner {
    public func sign(hashes: [Data], walletPublicKey: Wallet.PublicKey) -> AnyPublisher<[Data], Error> {
        Deferred {
            Future { [weak self] promise in
                guard let self = self else {
                    promise(.failure(WalletError.empty))
                    return
                }
                
                return self.sdk.sign(
                    hashes: hashes,
                    walletPublicKey: walletPublicKey.seedKey,
                    cardId: self.cardId,
                    derivationPath: walletPublicKey.derivationPath,
                    initialMessage: self.initialMessage
                ) { signResult in
                    switch signResult {
                    case .success(let response):
                        promise(.success(response.signatures))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func sign(hash: Data, walletPublicKey: Wallet.PublicKey) -> AnyPublisher<Data, Error> {
        sign(hashes: [hash], walletPublicKey: walletPublicKey)
            .map {
                $0.first ?? Data()
            }
            .eraseToAnyPublisher()
    }
}
