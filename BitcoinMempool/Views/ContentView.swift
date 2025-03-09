//
//  ContentView.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import SwiftUI


struct ContentView: View {
    // State to track the current tab
    
    @StateObject private var tabState = TabState()
    
    var body: some View {
        TabView(selection: $tabState.selectedTab) {
            // Dashboard Tab
            NavigationView {
                DashboardViewModel.DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }
            .tag(0)
            
            
            NavigationView {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            NavigationView {
                BlocksView()
            }
            .tabItem {
                Label("Blocks", systemImage: "square.stack.3d.up.fill")
            }
            .tag(2)
            
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)


        }
        .environmentObject(tabState)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
