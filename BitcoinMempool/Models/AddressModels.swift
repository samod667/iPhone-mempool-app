import Foundation

// MARK: - Address Info
struct AddressInfo: Codable {
    let address: String
    let chainStats: AddressStats
    let mempoolStats: AddressStats
    
    enum CodingKeys: String, CodingKey {
        case address
        case chainStats = "chain_stats"
        case mempoolStats = "mempool_stats"
    }
}

// MARK: - Address Stats
struct AddressStats: Codable {
    let funded_txo_count: Int
    let funded_txo_sum: Int
    let spent_txo_count: Int
    let spent_txo_sum: Int
    let tx_count: Int
}

// MARK: - Address Balance
struct AddressBalance: Codable {
    let confirmed: Int
    let unconfirmed: Int
    
    var total: Int {
        return confirmed + unconfirmed
    }
    
    // Convert balance to BTC (1 BTC = 100,000,000 satoshis)
    var confirmedBTC: Double {
        return Double(confirmed) / 100_000_000.0
    }
    
    var unconfirmedBTC: Double {
        return Double(unconfirmed) / 100_000_000.0
    }
    
    var totalBTC: Double {
        return Double(total) / 100_000_000.0
    }
}

// MARK: - Address UTXO
struct AddressUtxo: Codable {
    let txid: String
    let vout: Int
    let status: UTXOStatus
    let value: Int
}

// MARK: - UTXO Status
struct UTXOStatus: Codable {
    let confirmed: Bool
    let block_height: Int?
    let block_hash: String?
    let block_time: Int?
}

