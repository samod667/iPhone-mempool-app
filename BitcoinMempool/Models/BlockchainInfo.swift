//
//  BlockchainInfo.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import SwiftUI
import Foundation

/// Basic information about the Bitcoin blockchain
struct BlockchainInfo: Codable {
    /// Current block height
    let height: Int
    /// Current mining difficulty
    let difficulty: Double
    /// Hash of the latest block
    let bestBlockHash: String
    
    enum CodingKeys: String, CodingKey {
        case height
        case difficulty
        case bestBlockHash = "best_block_hash"
    }
}

/// Detailed information about a Bitcoin block
struct Block: Codable, Identifiable {
    /// Block hash (unique identifier)
    let id: String
    /// Block height
    let height: Int
    /// Block version
    let version: Int
    /// Block timestamp
    let timestamp: Int
    /// Number of transactions in the block
    let txCount: Int
    /// Block size in bytes
    let size: Int
    /// Block weight in weight units
    let weight: Int
    /// Merkle root hash of the block transactions
    let merkleRoot: String
    /// Hash of the previous block
    let previousBlockHash: String?
    /// Mining difficulty when the block was mined
    let difficulty: Double
    /// Nonce value used in mining
    let nonce: Int
    /// Block bits (compact form of target)
    let bits: Int
    /// Median timestamp of recent blocks
    let mediantime: Int
    
    /// Median fee rate - not provided by API, used for UI consistency
    var medianFee: Double { return 0.0 }
    
    /// Fee range - not provided by API, used for UI consistency
    var feeRange: [Double] { return [] }
    
    enum CodingKeys: String, CodingKey {
        case id
        case height
        case version
        case timestamp
        case txCount = "tx_count"
        case size
        case weight
        case merkleRoot = "merkle_root"
        case previousBlockHash = "previousblockhash"
        case difficulty
        case nonce
        case bits
        case mediantime
    }
}

/// Represents a block waiting to be mined (in mempool)
struct PendingBlock: Identifiable {
    /// Unique identifier for SwiftUI
    let id = UUID()
    /// Average fee rate for the block in sat/vB
    let blockFeeRate: Double
    /// Minimum and maximum fee range (min, max) in sat/vB
    let feeRange: (Double, Double)
    /// Total BTC value in the block
    let totalBTC: Double
    /// Number of transactions in the block
    let txCount: Int
    /// Estimated minutes until the block is mined
    let minutesUntilMining: Int
    
    /// Formatted fee rate string for display
    var formattedFeeRate: String {
        return String(format: "~%.0f sat/vB", blockFeeRate)
    }
    
    /// Formatted fee range string for display
    var formattedFeeRange: String {
        if feeRange.0 == feeRange.1 {
            return "\(Int(feeRange.0)) sat/vB"
        } else {
            return "\(Int(feeRange.0)) - \(Int(feeRange.1)) sat/vB"
        }
    }
    
    /// Formatted BTC amount for display
    var formattedBTC: String {
        return String(format: "%.3f BTC", totalBTC)
    }
    
    /// Color representing fee level for UI
    var color: Color {
        if blockFeeRate >= 8 {
            return Color.highFee.opacity(0.9)
        } else if blockFeeRate >= 5 {
            return Color.mediumFee.opacity(0.9)
        } else {
            return Color.lowFee.opacity(0.9)
        }
    }
}

/// Manages and tracks current state of the Bitcoin blockchain
class BlockchainStateManager: ObservableObject {
    /// Shared singleton instance
    static let shared = BlockchainStateManager()
    
    /// Current Bitcoin block height
    @Published private(set) var currentBlockHeight: Int = 0
    
    /// Last time the block height was updated
    @Published private(set) var lastUpdated: Date?
    
    private let apiClient = MempoolAPIClient.shared
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 120 // 2 minutes
    
    /// Initialize and start background refresh
    init() {
        startPeriodicRefresh()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    /// Start a background task to periodically refresh the block height
    func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshBlockHeight()
                try? await Task.sleep(nanoseconds: UInt64((self?.refreshInterval ?? 120) * 1_000_000_000))
            }
        }
    }
    
    /// Fetch the current block height from the API
    func refreshBlockHeight() async {
        do {
            let endpoint = "/blocks/tip/height"
            let (data, _) = try await apiClient.fetchData(from: endpoint)
            
            if let heightString = String(data: data, encoding: .utf8),
               let height = Int(heightString) {
                await MainActor.run {
                    self.currentBlockHeight = height
                    self.lastUpdated = Date()
                }
            }
        } catch {
            print("Failed to refresh block height: \(error)")
        }
    }
    
    /// Calculate confirmations for a transaction based on its block height
    /// - Parameter blockHeight: The height of the block containing the transaction
    /// - Returns: Number of confirmations, or nil if invalid height
    func getConfirmations(forBlockHeight blockHeight: Int?) -> Int? {
        guard let blockHeight = blockHeight,
              currentBlockHeight > 0,
              blockHeight <= currentBlockHeight
        else {
            return nil
        }
        return currentBlockHeight - blockHeight + 1
    }
}
