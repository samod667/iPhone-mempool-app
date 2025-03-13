//
//  AddressModels.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation

/// Represents complete information about a Bitcoin address
struct AddressInfo: Codable {
    /// Bitcoin address string
    let address: String
    /// On-chain statistics for this address
    let chainStats: AddressStats
    /// Mempool statistics for this address (unconfirmed transactions)
    let mempoolStats: AddressStats
    
    enum CodingKeys: String, CodingKey {
        case address
        case chainStats = "chain_stats"
        case mempoolStats = "mempool_stats"
    }
}

/// Statistical data for a Bitcoin address
struct AddressStats: Codable {
    /// Number of outputs funding this address
    let funded_txo_count: Int
    /// Total satoshis received by this address
    let funded_txo_sum: Int
    /// Number of outputs spending from this address
    let spent_txo_count: Int
    /// Total satoshis spent from this address
    let spent_txo_sum: Int
    /// Total number of transactions involving this address
    let tx_count: Int
}

/// Balance information for a Bitcoin address
struct AddressBalance: Codable {
    /// Confirmed balance in satoshis
    let confirmed: Int
    /// Unconfirmed balance in satoshis
    let unconfirmed: Int
    
    /// Total balance (confirmed + unconfirmed) in satoshis
    var total: Int {
        return confirmed + unconfirmed
    }
    
    /// Confirmed balance in BTC
    var confirmedBTC: Double {
        return Double(confirmed) / 100_000_000.0
    }
    
    /// Unconfirmed balance in BTC
    var unconfirmedBTC: Double {
        return Double(unconfirmed) / 100_000_000.0
    }
    
    /// Total balance in BTC
    var totalBTC: Double {
        return Double(total) / 100_000_000.0
    }
}

/// Unspent transaction output (UTXO) for a Bitcoin address
struct AddressUtxo: Codable {
    /// Transaction ID containing this UTXO
    let txid: String
    /// Output index in the transaction
    let vout: Int
    /// Status information about this UTXO
    let status: UTXOStatus
    /// Value of the UTXO in satoshis
    let value: Int
}

/// Status information for a UTXO
struct UTXOStatus: Codable {
    /// Whether the UTXO is confirmed in a block
    let confirmed: Bool
    /// Block height where the UTXO was confirmed (if confirmed)
    let block_height: Int?
    /// Block hash where the UTXO was confirmed (if confirmed)
    let block_hash: String?
    /// Block timestamp when the UTXO was confirmed (if confirmed)
    let block_time: Int?
}
