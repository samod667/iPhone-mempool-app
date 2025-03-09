//
//  BlockchainInfo.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import SwiftUI
import Foundation

struct BlockchainInfo: Codable {
    let height: Int
    let difficulty: Double
    let bestBlockHash: String
    
    enum CodingKeys: String, CodingKey {
        case height
        case difficulty
        case bestBlockHash = "best_block_hash"
    }
}

struct Block: Codable, Identifiable {
    let id: String
    let height: Int
    let version: Int
    let timestamp: Int
    let txCount: Int
    let size: Int
    let weight: Int
    let merkleRoot: String
    let previousBlockHash: String?
    let difficulty: Double
    let nonce: Int
    let bits: Int
    let mediantime: Int
    
    // Default value for median fee since it's not in the API
    var medianFee: Double { return 0.0 }
    // Default value for fee range since it's not in the API
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

struct PendingBlock: Identifiable {
    let id = UUID()
    let blockFeeRate: Double      // Average fee rate for the block (~1 sat/vB, ~2 sat/vB)
    let feeRange: (Double, Double) // Min-Max fee range (e.g., 1-1 sat/vB or 1-800 sat/vB)
    let totalBTC: Double          // Total BTC value (e.g., 0.01 BTC, 0.043 BTC)
    let txCount: Int              // Number of transactions (e.g., 52, 3335)
    let minutesUntilMining: Int   // Estimated time until mining (e.g., 69, 9)
    
    // Calculated properties for display
    var formattedFeeRate: String {
        return String(format: "~%.0f sat/vB", blockFeeRate)
    }
    
    var formattedFeeRange: String {
        if feeRange.0 == feeRange.1 {
            return "\(Int(feeRange.0)) sat/vB"
        } else {
            return "\(Int(feeRange.0)) - \(Int(feeRange.1)) sat/vB"
        }
    }
    
    var formattedBTC: String {
        return String(format: "%.3f BTC", totalBTC)
    }
    
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

// BlockchainStateManager - Manages current blockchain state
class BlockchainStateManager: ObservableObject {
    static let shared = BlockchainStateManager()
    
    @Published private(set) var currentBlockHeight: Int = 0
    @Published private(set) var lastUpdated: Date?
    
    private let apiClient = MempoolAPIClient.shared
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 120 // 2 minutes
    
    init() {
        startPeriodicRefresh()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    // Start a background task to periodically refresh the block height
    func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshBlockHeight()
                try? await Task.sleep(nanoseconds: UInt64((self?.refreshInterval ?? 120) * 1_000_000_000))
            }
        }
    }
    
    // Fetch the current block height from the API
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
                print("Updated current block height: \(height)")
            }
        } catch {
            print("Failed to refresh block height: \(error)")
        }
    }
    
    // Calculate confirmations for a transaction
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
