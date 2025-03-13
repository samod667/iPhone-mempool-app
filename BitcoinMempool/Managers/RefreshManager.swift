//
//  RefreshManager.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation
import SwiftUI
import Combine

/// Manages automatic and manual data refreshing throughout the app
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
    
    /// Indicates if auto refresh is enabled in settings
    var isAutoRefreshEnabled: Bool {
        return refreshInterval > 0
    }
    
    init() {
        setupTimer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Setup or update timer based on user settings
    private func setupTimer() {
        timer?.invalidate()
        timer = nil
        
        guard refreshInterval > 0 else { return }
        
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(refreshInterval),
            repeats: true
        ) { [weak self] _ in
            self?.refreshAll()
        }
    }
    
    /// Handle settings changes
    @objc private func settingsChanged() {
        setupTimer()
    }
    
    /// Trigger refresh for all data types
    func refreshAll() {
        mempoolRefreshPublisher.send()
        blocksRefreshPublisher.send()
        searchRefreshPublisher.send()
    }
    
    /// Manually refresh mempool data
    func refreshMempool() {
        mempoolRefreshPublisher.send()
    }
    
    /// Manually refresh blocks data
    func refreshBlocks() {
        blocksRefreshPublisher.send()
    }
    
    /// Manually refresh search data
    func refreshSearch() {
        searchRefreshPublisher.send()
    }
}

// MARK: - SwiftUI Extensions

/// Extension for SwiftUI Views to easily subscribe to refresh events
extension View {
    /// Subscribe to auto-refresh events
    /// - Parameters:
    ///   - target: The type of data to refresh
    ///   - action: Callback to execute when refresh is triggered
    /// - Returns: Modified view with refresh subscription
    func onAutoRefresh(target: RefreshTarget, perform action: @escaping () -> Void) -> some View {
        self.onReceive(target.publisher) { _ in
            action()
        }
    }
}

/// Enum to specify which refresh publisher to use
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
