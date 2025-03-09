//
//  BitcoinMempoolApp.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import SwiftUI

@main
struct BitcoinMempoolApp: App {
    // Initialize the blockchain state manager
    @StateObject private var blockchainState = BlockchainStateManager.shared
    
    init() {
        // Ensure Bitcoin price is fetched when app launches
        MempoolAPIClient.shared.refreshBitcoinPrice()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockchainState)
        }
    }
}
