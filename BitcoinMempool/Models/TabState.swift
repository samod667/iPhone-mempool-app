//
//  TabState.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation
import SwiftUI

/// Manages the selected tab state for the app's tab bar interface
class TabState: ObservableObject {
    /// Currently selected tab index:
    /// - 0: Dashboard
    /// - 1: Search
    /// - 2: Blocks
    /// - 3: Settings
    @Published var selectedTab: Int = 0
    
    /// Programmatically switch to the Blocks tab
    func switchToBlocksTab() {
        selectedTab = 2
    }
}
