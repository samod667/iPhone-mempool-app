//
//  RefreshManager.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation
import SwiftUI
import Combine

class RefreshManager: ObservableObject {
    static let shared = RefreshManager()
    
    // Publishers for different data types
    let mempoolRefreshPublisher = PassthroughSubject<Void, Never>()
    let blocksRefreshPublisher = PassthroughSubject<Void, Never>()
    let searchRefreshPublisher = PassthroughSubject<Void, Never>()
    
    private var timer: Timer?
    private var refreshInterval: Int {
        return UserDefaults.standard.integer(forKey: "autoRefreshInterval")
    }
    
    // Check if auto refresh is enabled
    var isAutoRefreshEnabled: Bool {
        return refreshInterval > 0
    }
    
    init() {
        // Start timer if interval is set
        setupTimer()
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(settingsChanged),
                                              name: UserDefaults.didChangeNotification,
                                              object: nil)
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // Setup or update timer based on settings
    private func setupTimer() {
        // Cancel existing timer
        timer?.invalidate()
        timer = nil
        
        // If auto refresh is disabled, return
        guard refreshInterval > 0 else {
            print("Auto refresh disabled")
            return
        }
        
        print("Setting up refresh timer for \(refreshInterval) seconds")
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval),
                                    repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }
    
    // Settings changed notification handler
    @objc private func settingsChanged() {
        setupTimer()
    }
    
    // Trigger all refresh publishers
    func refreshAll() {
        print("Auto-refreshing data...")
        mempoolRefreshPublisher.send()
        blocksRefreshPublisher.send()
        searchRefreshPublisher.send()
    }
    
    // Manually trigger refresh for a specific section
    func refreshMempool() {
        mempoolRefreshPublisher.send()
    }
    
    func refreshBlocks() {
        blocksRefreshPublisher.send()
    }
    
    func refreshSearch() {
        searchRefreshPublisher.send()
    }
}

// Extension for SwiftUI Views to easily subscribe to refresh events
extension View {
    func onAutoRefresh(target: RefreshTarget, perform action: @escaping () -> Void) -> some View {
        self.onReceive(target.publisher) { _ in
            action()
        }
    }
}

// Enum to specify which refresh publisher to use
enum RefreshTarget {
    case mempool
    case blocks
    case search
    case all
    
    var publisher: AnyPublisher<Void, Never> {
        switch self {
        case .mempool:
            return RefreshManager.shared.mempoolRefreshPublisher.eraseToAnyPublisher()
        case .blocks:
            return RefreshManager.shared.blocksRefreshPublisher.eraseToAnyPublisher()
        case .search:
            return RefreshManager.shared.searchRefreshPublisher.eraseToAnyPublisher()
        case .all:
            return Publishers.Merge3(
                RefreshManager.shared.mempoolRefreshPublisher,
                RefreshManager.shared.blocksRefreshPublisher,
                RefreshManager.shared.searchRefreshPublisher
            ).eraseToAnyPublisher()
        }
    }
}
