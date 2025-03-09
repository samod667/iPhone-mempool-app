//
//  TabState.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 05/03/2025.
//

import Foundation
import SwiftUI

// A class to hold the app's tab selection state
class TabState: ObservableObject {
    @Published var selectedTab: Int = 0
    
    func switchToBlocksTab() {
        selectedTab = 2 // Index 2 corresponds to the Blocks tab
    }
}
