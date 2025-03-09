//
//  Transaction.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import Foundation

struct Transaction: Codable, Identifiable {
    let id: String
    let fee: Double
    let vsize: Int
    let value: Int
    var size: Int
    var weight: Int?
    var statusObject: TransactionStatus?
    var status: String?
    var timestamp: Int?
    var blockHeight: Int?
    var vin: [TransactionInput]?
    var vout: [TransactionOutput]?
    
    // Calculate fee rate in sat/vB with safeguards
    var feeRate: Double {
        // Avoid division by zero and handle historical transactions
        guard vsize > 0 else { return 0.0 }
        
        // Fee is stored in BTC, convert to satoshis before calculating rate
        let feeInSatoshis = fee * 100_000_000
        return feeInSatoshis / Double(vsize)
    }
    
    // Format fee for display, detecting abnormally large values
    var formattedFee: String {
        // If fee is suspiciously large (more than 1 BTC), it's likely in satoshis already
        if fee > 1.0 {
            // Convert from satoshis to BTC for display
            return String(format: "%.8f BTC", fee / 100_000_000)
        } else {
            return String(format: "%.8f BTC", fee)
        }
    }
    
    // Display weight with validation
    var formattedWeight: String {
        guard let w = weight, w > 0 else {
            return "N/A" // For pre-SegWit transactions
        }
        return "\(w) WU"
    }
    
    // Display vsize with validation
    var formattedVSize: String {
        if vsize > 0 {
            return "\(vsize) vB"
        } else {
            return "N/A" // For pre-SegWit transactions
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "txid"
        case fee
        case vsize
        case value
        case size
        case weight
        case statusObject = "status"
        case timestamp = "blocktime"
        case vin
        case vout
    }
    
    init(id: String, fee: Double, vsize: Int, value: Int) {
        self.id = id
        self.fee = fee
        self.vsize = vsize
        self.value = value
        self.size = vsize
        self.weight = nil
        self.statusObject = nil
        self.status = nil
        self.timestamp = nil
        self.blockHeight = nil
        self.vin = nil
        self.vout = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Get the ID right away
        id = try container.decode(String.self, forKey: .id)
        
        // Create temporary variables for properties we need to modify
        var tempVsize = try container.decodeIfPresent(Int.self, forKey: .vsize) ?? 0
        var tempFee = try container.decodeIfPresent(Double.self, forKey: .fee) ?? 0.0
        
        // Handle other optional values
        value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 0
        size = try container.decodeIfPresent(Int.self, forKey: .size) ?? tempVsize
        weight = try container.decodeIfPresent(Int.self, forKey: .weight)
        timestamp = try container.decodeIfPresent(Int.self, forKey: .timestamp)
        
        // Parse status object
        statusObject = try container.decodeIfPresent(TransactionStatus.self, forKey: .statusObject)
        
        // Set status string and blockHeight based on statusObject
        if let statusObj = statusObject {
            status = statusObj.confirmed ? "Confirmed" : "Unconfirmed"
            blockHeight = statusObj.block_height
            
            // If timestamp is not set but block_time is available in status, use that
            if timestamp == nil {
                timestamp = statusObj.block_time
            }
        } else {
            status = "Unknown"
            blockHeight = nil
        }
        
        // Parse input and output data
        vin = try container.decodeIfPresent([TransactionInput].self, forKey: .vin)
        vout = try container.decodeIfPresent([TransactionOutput].self, forKey: .vout)
        
        // Handle historical transactions (pre-SegWit)
        if weight == nil || weight == 0 {
            // For historical transactions, weight is size * 4
            weight = size > 0 ? size * 4 : nil
        }
        
        // Fix vsize for historical transactions
        if tempVsize == 0 && size > 0 {
            // For historical transactions, vsize is approximately size
            tempVsize = size
        }
        
        // Fix fee value for historical transactions
        // If fee seems very high, it's likely in satoshis already
        if tempFee > 1.0 {
            tempFee = tempFee / 100_000_000 // Convert satoshis to BTC
        }
        
        // Now set the final values
        vsize = tempVsize
        fee = tempFee
    }
    
    // Calculate confirmations using BlockchainStateManager
    var confirmations: Int? {
        return BlockchainStateManager.shared.getConfirmations(forBlockHeight: blockHeight)
    }
}

// MARK: - Transaction Input & Other structs remain the same

// MARK: - Transaction Input
struct TransactionInput: Codable {
    let txid: String?
    let vout: Int?
    let prevout: PrevOutput?
    let scriptsig: String?
    let scriptsig_asm: String?
    let witness: [String]?
    let is_coinbase: Bool?
    let sequence: Int?
    
    enum CodingKeys: String, CodingKey {
        case txid
        case vout
        case prevout
        case scriptsig
        case scriptsig_asm
        case witness
        case is_coinbase
        case sequence
    }
}

// MARK: - Previous Output
struct PrevOutput: Codable {
    let scriptpubkey: String?
    let scriptpubkey_asm: String?
    let scriptpubkey_type: String?
    let scriptpubkey_address: String?
    let value: Int
    
    enum CodingKeys: String, CodingKey {
        case scriptpubkey
        case scriptpubkey_asm
        case scriptpubkey_type
        case scriptpubkey_address
        case value
    }
}

// MARK: - Transaction Output
struct TransactionOutput: Codable {
    let scriptpubkey: String?
    let scriptpubkey_asm: String?
    let scriptpubkey_type: String?
    let scriptpubkey_address: String?
    let value: Int
    
    enum CodingKeys: String, CodingKey {
        case scriptpubkey
        case scriptpubkey_asm
        case scriptpubkey_type
        case scriptpubkey_address
        case value
    }
}

struct TransactionStatus: Codable {
    let confirmed: Bool
    let block_height: Int?
    let block_hash: String?
    let block_time: Int?
}
