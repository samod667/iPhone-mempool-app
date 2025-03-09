//
//  MempoolStats.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import Foundation

struct MempoolStats: Codable {
    let count: Int
    let vsize: Int
    let totalFee: Double
    let feeHistogram: [[Double]]?
    
    enum CodingKeys: String, CodingKey {
        case count
        case vsize
        case totalFee = "total_fee"
        case feeHistogram = "fee_histogram"
    }
    
    
    var mempoolSize: Int { return count }
    var totalFeeInSatoshis: Int { return Int(totalFee) }
}

struct MempoolSummary: Codable {
    let mempoolSize: Int
    let unconfirmedTxs: Int
    let vsize: Int
    let totalFee: Double
    let medianFee: Double
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

struct FeeLevel: Codable {
    let feeRate: Double
    let vsize: Int
}
