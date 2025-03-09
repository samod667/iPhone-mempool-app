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
    
    // Initialize refresh manager
    @StateObject private var refreshManager = RefreshManager.shared
    
    init() {
        // Ensure Bitcoin price is fetched when app launches
        MempoolAPIClient.shared.refreshBitcoinPrice()
        
        // Initialize cache with settings
        let cacheDuration = UserDefaults.standard.integer(forKey: "cacheDuration")
        print("Using cache duration: \(cacheDuration) minutes")
        
        // Initialize notification permissions if enabled
        if UserDefaults.standard.bool(forKey: "enablePushNotifications") {
            NotificationsManager.shared.requestPermissions()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockchainState)
                .environmentObject(refreshManager)
        }
    }
}
