//
//  Transaction.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation

/// Represents a Bitcoin transaction with all its details
struct Transaction: Codable, Identifiable {
    /// Transaction ID (txid)
    let id: String
    
    /// Transaction fee in BTC
    let fee: Double
    
    /// Virtual size in vBytes
    let vsize: Int
    
    /// Transaction value in satoshis
    let value: Int
    
    /// Size in bytes
    var size: Int
    
    /// Weight units (optional)
    var weight: Int?
    
    /// Transaction confirmation status
    var statusObject: TransactionStatus?
    
    /// Status string ("Confirmed", "Unconfirmed", "Unknown")
    var status: String?
    
    /// Transaction timestamp
    var timestamp: Int?
    
    /// Block height where transaction was confirmed
    var blockHeight: Int?
    
    /// Transaction inputs
    var vin: [TransactionInput]?
    
    /// Transaction outputs
    var vout: [TransactionOutput]?
    
    /// Calculate fee rate in sat/vB with safeguards
    var feeRate: Double {
        guard vsize > 0 else { return 0.0 }
        
        let feeInSatoshis = fee * 100_000_000
        return feeInSatoshis / Double(vsize)
    }
    
    /// Format fee for display, detecting abnormally large values
    var formattedFee: String {
        if fee > 1.0 {
            // Likely in satoshis already, convert to BTC
            return String(format: "%.8f BTC", fee / 100_000_000)
        } else {
            return String(format: "%.8f BTC", fee)
        }
    }
    
    /// Display weight with validation
    var formattedWeight: String {
        guard let w = weight, w > 0 else {
            return "N/A" // For pre-SegWit transactions
        }
        return "\(w) WU"
    }
    
    /// Display vsize with validation
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
    
    /// Create a simple transaction with minimal information
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
    
    /// Decode transaction from JSON, handling potential data inconsistencies
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required field
        id = try container.decode(String.self, forKey: .id)
        
        // Handle potentially inconsistent data
        var tempVsize = try container.decodeIfPresent(Int.self, forKey: .vsize) ?? 0
        var tempFee = try container.decodeIfPresent(Double.self, forKey: .fee) ?? 0.0
        
        // Optional fields with sensible defaults
        value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 0
        size = try container.decodeIfPresent(Int.self, forKey: .size) ?? tempVsize
        weight = try container.decodeIfPresent(Int.self, forKey: .weight)
        timestamp = try container.decodeIfPresent(Int.self, forKey: .timestamp)
        
        // Handle status object
        statusObject = try container.decodeIfPresent(TransactionStatus.self, forKey: .statusObject)
        
        if let statusObj = statusObject {
            status = statusObj.confirmed ? "Confirmed" : "Unconfirmed"
            blockHeight = statusObj.block_height
            
            // Use block_time if timestamp is missing
            if timestamp == nil {
                timestamp = statusObj.block_time
            }
        } else {
            status = "Unknown"
            blockHeight = nil
        }
        
        // Transaction inputs and outputs
        vin = try container.decodeIfPresent([TransactionInput].self, forKey: .vin)
        vout = try container.decodeIfPresent([TransactionOutput].self, forKey: .vout)
        
        // Handle historical transactions (pre-SegWit)
        if weight == nil || weight == 0 {
            weight = size > 0 ? size * 4 : nil
        }
        
        if tempVsize == 0 && size > 0 {
            tempVsize = size
        }
        
        // Normalize fee value (some APIs return in satoshis, some in BTC)
        if tempFee > 1.0 {
            tempFee = tempFee / 100_000_000 // Convert satoshis to BTC
        }
        
        vsize = tempVsize
        fee = tempFee
    }
    
    /// Calculate confirmations using the current blockchain state
    var confirmations: Int? {
        return BlockchainStateManager.shared.getConfirmations(forBlockHeight: blockHeight)
    }
}

// MARK: - Transaction Input

/// Represents an input in a Bitcoin transaction
struct TransactionInput: Codable {
    /// Source transaction ID (for non-coinbase)
    let txid: String?
    
    /// Source output index (for non-coinbase)
    let vout: Int?
    
    /// Previous output details
    let prevout: PrevOutput?
    
    /// Script signature
    let scriptsig: String?
    
    /// Script signature in assembly format
    let scriptsig_asm: String?
    
    /// Witness data for SegWit transactions
    let witness: [String]?
    
    /// Whether this is a coinbase input (block reward)
    let is_coinbase: Bool?
    
    /// Sequence number
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

/// Details about the previous output being spent
struct PrevOutput: Codable {
    /// Script public key
    let scriptpubkey: String?
    
    /// Script public key in assembly format
    let scriptpubkey_asm: String?
    
    /// Script type (e.g., "p2pkh", "p2sh", "p2wpkh")
    let scriptpubkey_type: String?
    
    /// Address associated with this output
    let scriptpubkey_address: String?
    
    /// Value in satoshis
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

/// Represents an output in a Bitcoin transaction
struct TransactionOutput: Codable {
    /// Script public key
    let scriptpubkey: String?
    
    /// Script public key in assembly format
    let scriptpubkey_asm: String?
    
    /// Script type (e.g., "p2pkh", "p2sh", "p2wpkh")
    let scriptpubkey_type: String?
    
    /// Address associated with this output
    let scriptpubkey_address: String?
    
    /// Value in satoshis
    let value: Int
    
    enum CodingKeys: String, CodingKey {
        case scriptpubkey
        case scriptpubkey_asm
        case scriptpubkey_type
        case scriptpubkey_address
        case value
    }
}

/// Represents the confirmation status of a transaction
struct TransactionStatus: Codable {
    /// Whether the transaction is confirmed in a block
    let confirmed: Bool
    
    /// Height of the block containing the transaction (if confirmed)
    let block_height: Int?
    
    /// Hash of the block containing the transaction (if confirmed)
    let block_hash: String?
    
    /// Timestamp of the block containing the transaction (if confirmed)
    let block_time: Int?
}
