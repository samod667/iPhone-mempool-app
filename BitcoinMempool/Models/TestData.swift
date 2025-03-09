//
//  TestData.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import Foundation

struct TestData {
    static let sampleMempoolStats = MempoolStats(
        count: 15254,
        vsize: 21450789,
        totalFee: 1.23456,
        feeHistogram: [[1.5, 10000], [3.0, 20000], [5.0, 30000]]
    )
    
    static let sampleBlockchainInfo = BlockchainInfo(
        height: 775432,
        difficulty: 49.1234,
        bestBlockHash: "00000000000000000003a721efa8c4d0e760ec59f6847c7e2c4a6c4a9a72dd5a"
    )
    
    static let sampleTransactions = [
        Transaction(
            id: "1a2b3c4d5e6f7g8h9i0j",
            fee: 0.00012345,
            vsize: 1234,
            value: 4936
        ),
        Transaction(
            id: "9i8h7g6f5e4d3c2b1a0",
            fee: 0.00023456,
            vsize: 2345,
            value: 9380
        )
    ]
}
