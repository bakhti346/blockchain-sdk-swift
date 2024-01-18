//
//  Transaction.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 13.04.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation

public protocol TransactionParams {}

public struct Transaction {
    public let amount: Amount
    public internal(set) var fee: Fee
    public internal(set) var sourceAddress: String
    public internal(set) var destinationAddress: String
    public internal(set) var changeAddress: String
    public internal(set) var contractAddress: String?
    public var params: TransactionParams? = nil
    
    public init(
        amount: Amount,
        fee: Fee,
        sourceAddress: String,
        destinationAddress: String,
        changeAddress: String,
        contractAddress: String? = nil,
        params: TransactionParams? = nil
    ) {
        self.amount = amount
        self.fee = fee
        self.sourceAddress = sourceAddress
        self.destinationAddress = destinationAddress
        self.changeAddress = changeAddress
        self.contractAddress = contractAddress
        self.params = params
    }
}

extension Transaction: Equatable {
    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.amount == rhs.amount &&
        lhs.fee == rhs.fee &&
        lhs.sourceAddress == rhs.sourceAddress &&
        lhs.destinationAddress == rhs.destinationAddress &&
        lhs.changeAddress == rhs.changeAddress
    }
}

extension Transaction: ThenProcessable {}

public struct TransactionErrors: Error, LocalizedError, Equatable {
    public let errors: [TransactionError]
    
    public var errorDescription: String? {
        return errors.first?.localizedDescription
    }
}

public enum TransactionError: Error, LocalizedError, Equatable {
    case invalidAmount
    case amountExceedsBalance
    case invalidFee
    case feeExceedsBalance
    case totalExceedsBalance
    case dustAmount(minimumAmount: Amount)
    case dustChange(minimumAmount: Amount)
    case minimumBalance(minimumBalance: Amount)
        
    public var errorDescription: String? {
        switch self {
        case .amountExceedsBalance:
            return "send_validation_amount_exceeds_balance".localized
        case .dustAmount(let minimumAmount):
            return String(format: "send_error_dust_amount_format".localized, minimumAmount.description)
        case .dustChange(let minimumAmount):
           return String(format: "send_error_dust_change_format".localized, minimumAmount.description)
        case .minimumBalance(let minimumBalance):
            return String(format: "send_error_minimum_balance_format".localized, minimumBalance.string(roundingMode: .plain))
        case .feeExceedsBalance:
            return "send_validation_invalid_fee".localized
        case .invalidAmount:
            return "send_validation_invalid_amount".localized
        case .invalidFee:
            return "send_error_invalid_fee_value".localized
        case .totalExceedsBalance:
            return "send_validation_invalid_total".localized
        }
    }
}

extension Array where Element == TransactionError {
    mutating func appendIfNotNil(_ value: TransactionError?) {
        if let value = value {
            append(value)
        }
    }
}

protocol DustRestrictable {
    var dustValue: Amount { get }
}

protocol MinimumBalanceRestrictable {
    var minimumBalance: Amount { get }
}
