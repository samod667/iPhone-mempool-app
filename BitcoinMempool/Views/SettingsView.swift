//
//  SettingsView.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import SwiftUI
import UserNotifications

// ViewModel for Settings
class SettingsViewModel: ObservableObject {
    // Network settings
    @Published var selectedNetwork: BitcoinNetwork = .mainnet
    
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
        apiEndpoint = "https://mempool.space/api"
        useCustomEndpoint = false
        autoRefreshInterval = 60
        enablePushNotifications = false
        cacheDuration = 30
        saveSettings()
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetConfirmation = false
    @State private var showingCacheCleared = false
    @State private var showingNotificationPermissionAlert = false
    @State private var notificationPermissionStatus = false
    
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
                        // Update API endpoint when network changes
                        if !viewModel.useCustomEndpoint {
                            viewModel.apiEndpoint = viewModel.selectedNetwork.endpoint
                            // Update the API client's base URL
                            MempoolAPIClient.shared.updateBaseURL(to: viewModel.apiEndpoint)
                        }
                        viewModel.saveSettings()
                    }
                }
                
                // API settings section
                Section(header: Text("API Configuration")) {
                    Toggle("Use Custom API Endpoint", isOn: $viewModel.useCustomEndpoint)
                        .onChange(of: viewModel.useCustomEndpoint) { newValue in
                            if !newValue {
                                // If custom endpoint is disabled, revert to network endpoint
                                viewModel.apiEndpoint = viewModel.selectedNetwork.endpoint
                                MempoolAPIClient.shared.updateBaseURL(to: viewModel.apiEndpoint)
                            }
                            viewModel.saveSettings()
                        }
                    
                    if viewModel.useCustomEndpoint {
                        TextField("API Endpoint", text: $viewModel.apiEndpoint)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: viewModel.apiEndpoint) { newValue in
                                MempoolAPIClient.shared.updateBaseURL(to: newValue)
                                viewModel.saveSettings()
                            }
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
                    .onChange(of: viewModel.autoRefreshInterval) { newValue in
                        viewModel.saveSettings()
                        // Notify RefreshManager to update its timer
                        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
                        
                        if newValue > 0 {
                            // Trigger immediate refresh
                            Task {
                                RefreshManager.shared.refreshAll()
                            }
                        }
                    }
                    
                    Toggle("Enable Notifications", isOn: $viewModel.enablePushNotifications)
                        .onChange(of: viewModel.enablePushNotifications) { newValue in
                            viewModel.saveSettings()
                            
                            if newValue {
                                // If enabling notifications, request permission
                                checkAndRequestNotificationPermissions()
                            }
                        }
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
                    .onChange(of: viewModel.cacheDuration) { _ in
                        viewModel.saveSettings()
                    }
                    
                    Button(action: {
                        // Clear cache
                        CacheManager.shared.clearCache()
                        showingCacheCleared = true
                    }) {
                        Text("Clear Cache")
                            .foregroundColor(.red)
                    }
                }
                
                // Testing section for demo purposes
                Section(header: Text("Test Features")) {
                    Button("Test Auto Refresh") {
                        RefreshManager.shared.refreshAll()
                    }
                    
                    Button("Test Notification") {
                        NotificationsManager.shared.sendNotification(
                            title: "Test Notification",
                            body: "This is a test notification from Bitcoin Mempool app"
                        )
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
                    // Update API client when settings are reset
                    MempoolAPIClient.shared.updateBaseURL(to: viewModel.apiEndpoint)
                    // Notify RefreshManager to update timer
                    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
            .alert("Cache Cleared", isPresented: $showingCacheCleared) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The app cache has been cleared. This will force fresh data to be loaded from the network.")
            }
            .alert("Notification Permission", isPresented: $showingNotificationPermissionAlert) {
                Button("Settings", action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
                Button("OK", role: .cancel) { }
            } message: {
                if notificationPermissionStatus {
                    Text("Notifications are enabled. You'll receive updates for new blocks and significant mempool events.")
                } else {
                    Text("Notifications are disabled. Please go to Settings to enable them for Bitcoin Mempool.")
                }
            }
            .onAppear {
                // Check notification status when view appears
                checkNotificationStatus()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Check and request notification permissions if necessary
    private func checkAndRequestNotificationPermissions() {
        NotificationsManager.shared.checkNotificationStatus { authorized in
            if !authorized {
                // Request permissions
                NotificationsManager.shared.requestPermissions()
            }
            
            // Show the appropriate alert based on current status
            self.notificationPermissionStatus = authorized
            self.showingNotificationPermissionAlert = true
        }
    }
    
    // Check notification status and update toggle if necessary
    private func checkNotificationStatus() {
        NotificationsManager.shared.checkNotificationStatus { authorized in
            if viewModel.enablePushNotifications && !authorized {
                // Update UI if permissions were revoked
                DispatchQueue.main.async {
                    self.notificationPermissionStatus = authorized
                }
            }
        }
    }
}
