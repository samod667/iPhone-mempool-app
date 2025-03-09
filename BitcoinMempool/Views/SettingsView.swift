//
//  SettingsView.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import Foundation
//
//  SettingsView.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import SwiftUI

class SettingsViewModel: ObservableObject {
    // Network settings
    @Published var selectedNetwork: BitcoinNetwork = .mainnet
    
    // Display settings
    @Published var bitcoinUnit: BitcoinUnit = .btc
    @Published var feeRateUnit: FeeRateUnit = .satVbyte
    @Published var use24HourTime: Bool = true
    
    // API settings
    @Published var apiEndpoint: String = "https://mempool.space/api"
    @Published var useCustomEndpoint: Bool = false
    
    // App settings
    @Published var autoRefreshInterval: Int = 60 // seconds
    @Published var enablePushNotifications: Bool = false
    
    // Cache settings
    @Published var cacheDuration: Int = 30 // minutes
    
    // Load saved settings
    init() {
        loadSettings()
    }
    
    // Save settings to UserDefaults
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(selectedNetwork.rawValue, forKey: "selectedNetwork")
        defaults.set(bitcoinUnit.rawValue, forKey: "bitcoinUnit")
        defaults.set(feeRateUnit.rawValue, forKey: "feeRateUnit")
        defaults.set(use24HourTime, forKey: "use24HourTime")
        defaults.set(apiEndpoint, forKey: "apiEndpoint")
        defaults.set(useCustomEndpoint, forKey: "useCustomEndpoint")
        defaults.set(autoRefreshInterval, forKey: "autoRefreshInterval")
        defaults.set(enablePushNotifications, forKey: "enablePushNotifications")
        defaults.set(cacheDuration, forKey: "cacheDuration")
    }
    
    // Load settings from UserDefaults
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        if let networkValue = defaults.string(forKey: "selectedNetwork"),
           let network = BitcoinNetwork(rawValue: networkValue) {
            selectedNetwork = network
        }
        
        if let unitValue = defaults.string(forKey: "bitcoinUnit"),
           let unit = BitcoinUnit(rawValue: unitValue) {
            bitcoinUnit = unit
        }
        
        if let feeUnitValue = defaults.string(forKey: "feeRateUnit"),
           let feeUnit = FeeRateUnit(rawValue: feeUnitValue) {
            feeRateUnit = feeUnit
        }
        
        use24HourTime = defaults.bool(forKey: "use24HourTime")
        
        if let endpoint = defaults.string(forKey: "apiEndpoint") {
            apiEndpoint = endpoint
        }
        
        useCustomEndpoint = defaults.bool(forKey: "useCustomEndpoint")
        
        if defaults.object(forKey: "autoRefreshInterval") != nil {
            autoRefreshInterval = defaults.integer(forKey: "autoRefreshInterval")
        }
        
        enablePushNotifications = defaults.bool(forKey: "enablePushNotifications")
        
        if defaults.object(forKey: "cacheDuration") != nil {
            cacheDuration = defaults.integer(forKey: "cacheDuration")
        }
    }
    
    // Reset settings to defaults
    func resetSettings() {
        selectedNetwork = .mainnet
        bitcoinUnit = .btc
        feeRateUnit = .satVbyte
        use24HourTime = true
        apiEndpoint = "https://mempool.space/api"
        useCustomEndpoint = false
        autoRefreshInterval = 60
        enablePushNotifications = false
        cacheDuration = 30
        saveSettings()
    }
}

// Enums for settings options
enum BitcoinNetwork: String, CaseIterable, Identifiable {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
    case signet = "Signet"
    
    var id: String { self.rawValue }
    
    var endpoint: String {
        switch self {
        case .mainnet: return "https://mempool.space/api"
        case .testnet: return "https://mempool.space/testnet/api"
        case .signet: return "https://mempool.space/signet/api"
        }
    }
}

enum BitcoinUnit: String, CaseIterable, Identifiable {
    case btc = "BTC"
    case sats = "Satoshis"
    
    var id: String { self.rawValue }
    
    func format(_ value: Double) -> String {
        switch self {
        case .btc:
            return String(format: "%.8f BTC", value)
        case .sats:
            return "\(Int(value * 100_000_000)) sats"
        }
    }
}

enum FeeRateUnit: String, CaseIterable, Identifiable {
    case satVbyte = "sat/vB"
    case btcKb = "BTC/kB"
    
    var id: String { self.rawValue }
    
    func format(_ satPerVbyte: Double) -> String {
        switch self {
        case .satVbyte:
            return String(format: "%.2f sat/vB", satPerVbyte)
        case .btcKb:
            // Convert sat/vB to BTC/kB (1 kB = 1000 vBytes, 1 BTC = 100,000,000 sats)
            let btcPerKb = satPerVbyte * 1000 / 100_000_000
            return String(format: "%.8f BTC/kB", btcPerKb)
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetConfirmation = false
    @State private var showingCacheCleared = false
    
    var body: some View {
        NavigationView {
            List {
                // Network section
                Section(header: Text("Network")) {
                    Picker("Bitcoin Network", selection: $viewModel.selectedNetwork) {
                        ForEach(BitcoinNetwork.allCases) { network in
                            Text(network.rawValue).tag(network)
                        }
                    }
                    .onChange(of: viewModel.selectedNetwork) { _ in
                        if !viewModel.useCustomEndpoint {
                            viewModel.apiEndpoint = viewModel.selectedNetwork.endpoint
                        }
                        viewModel.saveSettings()
                    }
                }
                
                // Display settings section
                Section(header: Text("Display")) {
                    Picker("Bitcoin Unit", selection: $viewModel.bitcoinUnit) {
                        ForEach(BitcoinUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: viewModel.bitcoinUnit) { _ in viewModel.saveSettings() }
                    
                    Picker("Fee Rate Display", selection: $viewModel.feeRateUnit) {
                        ForEach(FeeRateUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: viewModel.feeRateUnit) { _ in viewModel.saveSettings() }
                    
                    Toggle("Use 24-Hour Time", isOn: $viewModel.use24HourTime)
                        .onChange(of: viewModel.use24HourTime) { _ in viewModel.saveSettings() }
                }
                
                // API settings section
                Section(header: Text("API Configuration")) {
                    Toggle("Use Custom API Endpoint", isOn: $viewModel.useCustomEndpoint)
                        .onChange(of: viewModel.useCustomEndpoint) { _ in viewModel.saveSettings() }
                    
                    if viewModel.useCustomEndpoint {
                        TextField("API Endpoint", text: $viewModel.apiEndpoint)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: viewModel.apiEndpoint) { _ in viewModel.saveSettings() }
                    }
                }
                
                // App settings section
                Section(header: Text("App Settings")) {
                    Picker("Auto Refresh", selection: $viewModel.autoRefreshInterval) {
                        Text("Off").tag(0)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                        Text("10 minutes").tag(600)
                    }
                    .onChange(of: viewModel.autoRefreshInterval) { _ in viewModel.saveSettings() }
                    
                    Toggle("Enable Notifications", isOn: $viewModel.enablePushNotifications)
                        .onChange(of: viewModel.enablePushNotifications) { _ in viewModel.saveSettings() }
                }
                
                // Cache settings section
                Section(header: Text("Cache")) {
                    Picker("Cache Duration", selection: $viewModel.cacheDuration) {
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("4 hours").tag(240)
                    }
                    .onChange(of: viewModel.cacheDuration) { _ in viewModel.saveSettings() }
                    
                    Button(action: {
                        // Clear cache
                        showingCacheCleared = true
                    }) {
                        Text("Clear Cache")
                            .foregroundColor(.red)
                    }
                }
                
                // About section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    Link("Source Code", destination: URL(string: "https://github.com/yourusername/BitcoinMempool")!)
                    
                    Link("Mempool.space", destination: URL(string: "https://mempool.space")!)
                }
                
                // Reset section
                Section {
                    Button(action: {
                        showingResetConfirmation = true
                    }) {
                        Text("Reset All Settings")
                            .foregroundColor(.red)
                    }
                }
                
                // Personal signature section
                Section {
                    HStack {
                        Spacer()
                        Text("made by dr. sam")
                            .font(.system(size: 14, weight: .light))
                            .italic()
                            .foregroundColor(.gray.opacity(0.8))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .listStyle(InsetGroupedListStyle())
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetSettings()
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
            .alert("Cache Cleared", isPresented: $showingCacheCleared) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The app cache has been cleared.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
