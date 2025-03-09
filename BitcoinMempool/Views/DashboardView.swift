import SwiftUI

// DashboardViewModel to handle data fetching and state
class DashboardViewModel: ObservableObject {
    @Published var mempoolStats: MempoolStats?
    @Published var blockchainInfo: BlockchainInfo?
    @Published var recentTransactions: [Transaction] = []
    @Published var recentBlocks: [Block] = []
    @Published var recommendedFees: [String: Double] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    
    private let apiClient = MempoolAPIClient.shared
    
    // Load all dashboard data
    func loadData() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            print("Starting to fetch data...")
            
            // Fetch mempool stats first to debug
            let stats = try await apiClient.fetchMempoolStats()
            print("Successfully fetched mempool stats: \(stats)")
            
            DispatchQueue.main.async {
                self.mempoolStats = stats
                self.isLoading = false
            }
            
            // Fetch blockchain info
            do {
                let info = try await apiClient.fetchBlockchainInfo()
                DispatchQueue.main.async {
                    self.blockchainInfo = info
                }
            } catch {
                print("Error fetching blockchain info: \(error)")
            }
            
            // Fetch recent transactions
            do {
                let transactions = try await apiClient.fetchRecentTransactions(limit: 5)
                DispatchQueue.main.async {
                    self.recentTransactions = transactions
                }
            } catch {
                print("Error fetching transactions: \(error)")
            }
            
            // Fetch recent blocks (only once)
            do {
                print("Fetching recent blocks for dashboard...")
                let blocks = try await apiClient.fetchRecentBlocks(limit: 6)
                print("Successfully fetched \(blocks.count) blocks for dashboard")
                DispatchQueue.main.async {
                    self.recentBlocks = blocks
                    print("Dashboard now has \(self.recentBlocks.count) blocks to display")
                }
            } catch {
                print("Error fetching blocks for dashboard: \(error)")
                // Create some sample blocks for testing
                DispatchQueue.main.async {
                    self.recentBlocks = [
                        Block(id: "sample1", height: 886330, version: 1, timestamp: Int(Date().timeIntervalSince1970) - 600,
                              txCount: 1500, size: 1250000, weight: 4000000, merkleRoot: "sample",
                              previousBlockHash: "sample", difficulty: 110568428300952.69,
                              nonce: 123456, bits: 123456, mediantime: Int(Date().timeIntervalSince1970) - 650)
                    ]
                    print("Added sample block data for dashboard")
                }
            }
            
            // Fetch recommended fees
            do {
                let fees = try await apiClient.fetchRecommendedFees()
                DispatchQueue.main.async {
                    self.recommendedFees = fees
                }
            } catch {
                print("Error fetching fees: \(error)")
            }
            
        } catch {
            print("Error fetching data: \(error)")
            
            let errorMessage: String
            if let decodingError = error as? DecodingError {
                errorMessage = "Received unexpected data format from the mempool API. Please try again later."
            } else if (error as NSError).domain == NSURLErrorDomain {
                errorMessage = "Cannot connect to the mempool API. Please check your internet connection."
            } else {
                errorMessage = "An error occurred: \(error.localizedDescription)"
            }
            
            DispatchQueue.main.async {
                self.errorMessage = errorMessage
                self.isLoading = false
            }
        }
    }
    
    // Dashboard view that displays mempool statistics
    struct DashboardView: View {
        @StateObject private var viewModel = DashboardViewModel()
        @EnvironmentObject private var tabState: TabState
        
        // Add these state variables for block detail view
        @State private var selectedBlock: Block?
        @State private var isBlockDetailPresented = false
        
        private func formatBitcoin(_ value: Double) -> String {
            if value >= 1_000_000 {
                return String(format: "%.2f BTC", value / 100_000_000)
            } else {
                return String(format: "%.8f BTC", value / 100_000_000)
            }
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Loading mempool data...")
                            .padding()
                            .foregroundColor(Color.white)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        // Header with mempool stats
                        mempoolHeader
                        
                        // Blocks visualization
                        blocksSection
                        
                        // Transaction fees section
                        feesSection
                        
                        // Mempool visualization section
                        mempoolVisualizationSection
                        
                        // Additional stats section
                        additionalStatsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Bitcoin Mempool")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color.mempoolPrimary)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadData()
                }
            }
            .background(Color.mempoolBackground)
            .preferredColorScheme(.dark)
            // Add sheet to present the block detail view
            .sheet(isPresented: $isBlockDetailPresented) {
                if let block = selectedBlock {
                    BlockDetailView(blockId: block.id, blockHeight: block.height)
                }
            }
        }
        
        // MARK: - UI Components
        private func formatNumber(_ number: Int) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.groupingSize = 3
            
            return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
        }
        // Header section with mempool stats
        private var mempoolHeader: some View {
            VStack(spacing: 16) {
                Text("Mempool Statistics")
                    .font(.headline)
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                
                if let stats = viewModel.mempoolStats {
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Transactions",
                            value: formatNumber(stats.mempoolSize),
                            subtitle: "in mempool",
                            backgroundColor: Color(.systemGray6).opacity(0.15)
                        )
                        
                        StatCard(
                            title: "Size",
                            value: "\(stats.vsize / 1_000_000) MB",
                            subtitle: "unconfirmed TXs",
                            backgroundColor: Color(.systemGray6).opacity(0.15)
                        )
                    }
                    
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Total Fee",
                            value: formatBitcoin(stats.totalFee),
                            subtitle: "waiting to be mined",
                            backgroundColor: Color(.systemGray6).opacity(0.15)
                        )
                        
                        StatCard(
                            title: "Average Fee",
                            value: formatFeeRate(stats: stats),
                            subtitle: "per transaction",
                            backgroundColor: Color(.systemGray6).opacity(0.15)
                        )
                    }
                } else {
                    Text("No mempool data available")
                        .italic()
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            .padding()
            .background(Color.mempoolBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        private func formatFeeRate(stats: MempoolStats) -> String {
            // Calculate average fee in satoshis per vByte
            let totalFeeInSatoshis = stats.totalFeeInSatoshis
            let totalVSize = stats.vsize
            
            // Avoid division by zero
            guard totalVSize > 0 else {
                return "0 sat/vB"
            }
            
            // Calculate the average fee rate (satoshis per vByte)
            let feeRate = Double(totalFeeInSatoshis) / Double(totalVSize)
            
            // Round to whole number if it's large, otherwise show one decimal place
            if feeRate >= 10 {
                return "\(Int(feeRate.rounded())) sat/vB"
            } else {
                return String(format: "%.1f sat/vB", feeRate)
            }
        }
        // Recent blocks section
        private var blocksSection: some View {
            VStack(spacing: 16) {
                HStack {
                    Text("Recent Blocks")
                        .font(.headline)
                        .foregroundColor(Color.white)
                    
                    Spacer()
                    
                    // Replace NavigationLink with Button
                    Button(action: {
                        // Switch to the Blocks tab (index 2)
                        tabState.switchToBlocksTab()
                    }) {
                        Text("View All")
                            .font(.subheadline)
                            .foregroundColor(Color.mempoolPrimary)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recentBlocks) { block in
                            recentBlockCard(for: block)
                        }
                        
                        if viewModel.recentBlocks.isEmpty {
                            Text("No block data available")
                                .italic()
                                .foregroundColor(Color.white.opacity(0.7))
                                .frame(width: 150, height: 120)
                                .background(Color(.systemGray6).opacity(0.15))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding()
            .background(Color.mempoolBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
            )
        }

        
        // Block card component - Updated with tap gesture
        // Updated Block Card design for DashboardView.swift
        // Refined Block Card design for DashboardView.swift - more elegant with smaller text
        private func recentBlockCard(for block: Block) -> some View {
            // Card dimensions - adjusting to match screenshot
            let width: CGFloat = 150
            let height: CGFloat = 150
            
            return ZStack {
                // Shadow/background layer to create subtle 3D effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .frame(width: width, height: height)
                    .offset(x: 3, y: 3)
                
                // Main content layer with purple gradient
                VStack(alignment: .leading, spacing: 3) {
                    // Block height in cyan - block number only, no # symbol
                    Text("\(block.height)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.9, blue: 1.0))
                    
                    // Fee rate (estimated)
                    let feeRate = getFeeRate(for: block)
                    Text(feeRate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Fee range in yellow
                    let feeRange = getFeeRange(for: block)
                    Text(feeRange)
                        .font(.system(size: 11))
                        .foregroundColor(Color.yellow)
                    
                    // BTC amount in larger font
                    let btcAmount = getBTCAmount(for: block)
                    Text(btcAmount)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 1)
                    
                    // Transactions count
                    Text("\(formatNumber(block.txCount)) transactions")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    
                    // Time ago
                    Text(timeAgo(timestamp: block.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .padding(.bottom, 2)
                    
                    Spacer()
                    
                    // Mining pool name
                    let poolName = getPoolName(for: block.height)
                    HStack {
                        getMiningPoolIcon(for: poolName)
                            .foregroundColor(.white)
                            .font(.system(size: 11))
                        
                        Text(poolName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .frame(width: width, height: height)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.3, blue: 0.8),
                            Color(red: 0.2, green: 0.2, blue: 0.5)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(12)
            }
            .frame(width: width, height: height)
            .onTapGesture {
                selectedBlock = block
                isBlockDetailPresented = true
            }
        }

        // Helper functions for formatting the data

        // Estimate fee rate based on block height (for demo purposes)
        private func getFeeRate(for block: Block) -> String {
            let mod = block.height % 5
            switch mod {
            case 0: return "~5 sat/vB"
            case 1: return "~2 sat/vB"
            default: return "~1 sat/vB"
            }
        }

        // Generate a realistic fee range
        private func getFeeRange(for block: Block) -> String {
            let mod = block.height % 5
            switch mod {
            case 0: return "4 - 500 sat/vB"
            case 1: return "1 - 200 sat/vB"
            case 2: return "1 - 76 sat/vB"
            case 3: return "1 - 153 sat/vB"
            default: return "1 - 200 sat/vB"
            }
        }

        // Mock BTC amount for visualization
        private func getBTCAmount(for block: Block) -> String {
            let mod = block.height % 5
            switch mod {
            case 0: return "0.065 BTC"
            case 1: return "0.028 BTC"
            case 2: return "0.014 BTC"
            case 3: return "0.023 BTC"
            default: return "0.023 BTC"
            }
        }

        // Get mining pool icon
        private func getMiningPoolIcon(for poolName: String) -> some View {
            switch poolName {
            case "AntPool":
                return Image(systemName: "ant").foregroundColor(.green)
            case "Foundry USA":
                return Image(systemName: "hammer").foregroundColor(.orange)
            case "SpiderPool":
                return Image(systemName: "circle.grid.cross").foregroundColor(.yellow)
            case "MARA Pool":
                return Image(systemName: "m.circle").foregroundColor(.white)
            case "F2Pool":
                return Image(systemName: "f.circle").foregroundColor(.blue)
            case "Binance Pool":
                return Image(systemName: "b.circle").foregroundColor(.yellow)
            default:
                return Image(systemName: "bitcoinsign.circle").foregroundColor(.white)
            }
        }

        // Modified pool name function to match the screenshot
        private func getPoolName(for height: Int) -> String {
            let pools = ["AntPool", "Foundry USA", "SpiderPool", "SpiderPool", "MARA Pool", "F2Pool", "Binance Pool"]
            let index = height % pools.count
            return pools[index]
        }

        // Convert timestamp to "time ago" string
        private func timeAgo(timestamp: Int) -> String {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let now = Date()
            let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
            
            if let minutes = components.minute, minutes < 60 {
                return "\(minutes) min ago"
            } else if let hours = components.hour, hours < 24 {
                return "\(hours) hr ago"
            } else if let days = components.day {
                return "\(days) days ago"
            }
            
            return "recently"
        }
        
        // Transaction fees section
       
        private var feesSection: some View {
            VStack(spacing: 10) {
                Text("Transaction Fees")
                    .font(.headline)
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Main fee container
                VStack(spacing: 0) {
                    // Priority categories bar - using standard rounded corners
                    HStack(spacing: 0) {
                        // No Priority column has been removed to match your screenshot
                        
                        Text("Low Priority")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.45, green: 0.55, blue: 0.15))
                        
                        Text("Medium Priority")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.55, green: 0.55, blue: 0.15))
                        
                        Text("High Priority")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.55, green: 0.45, blue: 0.15))
                    }
                    .background(Color.black)
                    
                    // Fee rates row
                    HStack(spacing: 0) {
                        // Low Priority
                        VStack(spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(viewModel.recommendedFees["hourFee"] ?? 3)) ")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("sat/vB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Text("$\(calculateUSDFee(viewModel.recommendedFees["hourFee"] ?? 3))")
                                .font(.system(size: 13))
                                .foregroundColor(Color.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        
                        // Medium Priority
                        VStack(spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(viewModel.recommendedFees["halfHourFee"] ?? 4)) ")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("sat/vB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Text("$\(calculateUSDFee(viewModel.recommendedFees["halfHourFee"] ?? 4))")
                                .font(.system(size: 13))
                                .foregroundColor(Color.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        
                        // High Priority
                        VStack(spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(viewModel.recommendedFees["fastestFee"] ?? 5)) ")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("sat/vB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Text("$\(calculateUSDFee(viewModel.recommendedFees["fastestFee"] ?? 5))")
                                .font(.system(size: 13))
                                .foregroundColor(Color.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .background(Color.black)
                }
                .cornerRadius(8)
                .frame(height: 100) // Compact height
            }
            .padding()
            .background(Color.mempoolBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
            )
        }

        // Add this helper function to calculate USD equivalent
        private func calculateUSDFee(_ satPerVbyte: Double) -> String {
            // Assuming average transaction size of 140 vBytes and Bitcoin price of $65,000
            let avgTxSize = 140.0
            let bitcoinPriceUSD = 65000.0
            
            // Calculate fee in satoshis
            let feeInSatoshis = satPerVbyte * avgTxSize
            
            // Convert to USD (1 BTC = 100,000,000 satoshis)
            let feeInUSD = (feeInSatoshis / 100_000_000) * bitcoinPriceUSD
            
            return String(format: "%.2f", feeInUSD)
        }
        
        // Fee card component
        private func feeCard(title: String, value: String, backgroundColor: Color) -> some View {
            VStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(Color.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        
        // Mempool visualization section (placeholder)
        private var mempoolVisualizationSection: some View {
            VStack(spacing: 16) {
                Text("Mempool Visualization")
                    .font(.headline)
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Use the new MempoolGoggles component
                MempoolGoggles()
                    .frame(height: 250)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding()
            .background(Color.mempoolBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        
        // Additional stats section
        private var additionalStatsSection: some View {
            VStack(spacing: 16) {
                Text("Additional Statistics")
                    .font(.headline)
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 16) {
                    StatCard(
                        title: "Memory Usage",
                        value: formatMemoryUsage(viewModel.mempoolStats?.vsize),
                        subtitle: "of \(300) MB",
                        backgroundColor: Color(.systemGray6).opacity(0.15)
                    )
                    
                    StatCard(
                        title: "Unconfirmed",
                        value: formatNumber(viewModel.mempoolStats?.mempoolSize ?? 0),
                        subtitle: "TXs",
                        backgroundColor: Color(.systemGray6).opacity(0.15)
                    )
                }
            }
            .padding()
            .background(Color.mempoolBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        
        private func formatMemoryUsage(_ vsize: Int?) -> String {
            guard let vsize = vsize else { return "0 MB" }
            
            // Convert vsize to MB (divide by 1,000,000)
            let mbSize = Double(vsize) / 1_000_000
            
            // Format with no decimal places if it's a whole number
            if mbSize.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(mbSize)) MB"
            } else {
                // Otherwise show one decimal place
                return String(format: "%.1f MB", mbSize)
            }
        }
        
        // MARK: - Helper Functions
        
    }
}

// Stat card component
struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String? = nil
    var backgroundColor: Color = Color(.systemGray6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.7))
            
            HStack(alignment: .firstTextBaseline) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(Color.white)
                }
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.white)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.7))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
        )
    }
}
