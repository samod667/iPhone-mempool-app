//
//  MempoolStats.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation

/// Statistics about the current state of the Bitcoin mempool
struct MempoolStats: Codable {
    /// Number of transactions in the mempool
    let count: Int
    
    /// Total virtual size of all transactions in the mempool (in vB)
    let vsize: Int
    
    /// Total fee value of all transactions in the mempool (in BTC)
    let totalFee: Double
    
    /// Fee distribution histogram [[fee_rate, vsize], ...] if available
    let feeHistogram: [[Double]]?
    
    enum CodingKeys: String, CodingKey {
        case count
        case vsize
        case totalFee = "total_fee"
        case feeHistogram = "fee_histogram"
    }
    
    /// Alias for count - number of transactions in mempool
    var mempoolSize: Int { return count }
    
    /// Total fee in satoshis instead of BTC
    var totalFeeInSatoshis: Int { return Int(totalFee) }
}

/// Comprehensive summary of the Bitcoin mempool state
struct MempoolSummary: Codable {
    /// Total number of transactions in the mempool
    let mempoolSize: Int
    
    /// Number of unconfirmed transactions
    let unconfirmedTxs: Int
    
    /// Total virtual size of all transactions (in vB)
    let vsize: Int
    
    /// Total fee amount in the mempool (in BTC)
    let totalFee: Double
    
    /// Median fee rate across all transactions (in sat/vB)
    let medianFee: Double
    
    /// Fee distribution by rate levels
    let feeHistogram: [FeeLevel]
    
    enum CodingKeys: String, CodingKey {
        case mempoolSize = "count"
        case unconfirmedTxs = "unconfirmed_count"
        case vsize
        case totalFee = "total_fee"
        case medianFee = "median_fee"
        case feeHistogram = "fee_histogram"
    }
}

/// Fee rate level entry in the mempool
struct FeeLevel: Codable {
    /// Fee rate in sat/vB
    let feeRate: Double
    
    /// Total vsize of transactions at this fee level
    let vsize: Int
}
