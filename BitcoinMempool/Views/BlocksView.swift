import Foundation
import SwiftUI

// View model as its own separate class
class BlocksViewModel: ObservableObject {
    @Published var recentBlocks: [Block] = []
    @Published var mempoolBlocks: [[String: Any]] = []
    @Published var pendingBlocks: [PendingBlock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = MempoolAPIClient.shared
    
    func loadData() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Fetch recent blocks
            print("Fetching recent blocks for BlocksView...")
            let blocks = try await apiClient.fetchRecentBlocks(limit: 10)
            print("Successfully fetched \(blocks.count) blocks for BlocksView")
            
            DispatchQueue.main.async {
                self.recentBlocks = blocks
                self.isLoading = false
                print("BlocksView now has \(self.recentBlocks.count) blocks to display")
            }
            
            // Fetch pending blocks using the new PendingBlock model
            await fetchPendingBlocks()
            
            // Keep the old mempool blocks fetching for backward compatibility
            do {
                print("Fetching mempool blocks (legacy method)...")
                let (mempoolData, _) = try await apiClient.fetchData(from: "/v1/mining/blocks/fees")
                
                if let jsonArray = try JSONSerialization.jsonObject(with: mempoolData) as? [[String: Any]] {
                    print("Successfully fetched \(jsonArray.count) mempool blocks")
                    DispatchQueue.main.async {
                        self.mempoolBlocks = jsonArray
                    }
                }
            } catch {
                print("Error fetching mempool blocks (legacy): \(error)")
            }
        } catch {
            print("Error fetching block data: \(error)")
            
            // Create fallback sample data
            DispatchQueue.main.async {
                self.recentBlocks = [
                    Block(id: "sample1", height: 886330, version: 1, timestamp: Int(Date().timeIntervalSince1970) - 600,
                          txCount: 1500, size: 1250000, weight: 4000000, merkleRoot: "sample",
                          previousBlockHash: "sample", difficulty: 110568428300952.69,
                          nonce: 123456, bits: 123456, mediantime: Int(Date().timeIntervalSince1970) - 650)
                ]
                self.errorMessage = "Could not connect to the mempool API. Using sample data."
                self.isLoading = false
            }
        }
    }
    
    func fetchPendingBlocks() async {
        do {
            // Fetch the mempool blocks data
            let endpoint = "/api/v1/mining/blocks/fees"
            let (data, _) = try await apiClient.fetchData(from: endpoint)
            
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var blocks: [PendingBlock] = []
                
                // Process all pending blocks from the API
                for (index, blockData) in jsonArray.enumerated() {
                    // Extract block data from JSON
                    let blockFeeRate = blockData["blockFeeRate"] as? Double ?? Double(index + 1)
                    let medianFeeRate = blockData["medianFeeRate"] as? Double ?? blockFeeRate
                    let totalFees = blockData["totalFees"] as? Double ?? Double(index + 1) * 1000000
                    let nTx = blockData["nTx"] as? Int ?? 50 * (index + 1)
                    
                    // Create the pending block model
                    let pendingBlock = PendingBlock(
                        blockFeeRate: blockFeeRate,
                        feeRange: (medianFeeRate, blockFeeRate),
                        totalBTC: totalFees / 100_000_000, // Convert satoshis to BTC
                        txCount: nTx,
                        minutesUntilMining: (index + 1) * 10 // ~10 min per block
                    )
                    
                    blocks.append(pendingBlock)
                }
                
                DispatchQueue.main.async {
                    self.pendingBlocks = blocks.sorted(by: { $0.minutesUntilMining < $1.minutesUntilMining })
                    print("Loaded \(blocks.count) pending blocks, sorted by mining time")
                }
            }
        } catch {
            print("Error fetching pending blocks: \(error)")
            
            // If we couldn't fetch real data, create more sample pending blocks
            DispatchQueue.main.async {
                self.pendingBlocks = self.createSamplePendingBlocks()
            }
        }
    }
    
    // Helper method to create sample pending blocks
    private func createSamplePendingBlocks() -> [PendingBlock] {
        // Create more sample data to demonstrate the scrolling functionality
        var sampleBlocks: [PendingBlock] = []
        
        // Create 10 sample blocks with varied data
        for i in 1...10 {
            // Create some variation in the blocks
            let feeRate = Double.random(in: 1.0...15.0)
            let maxFeeRate = feeRate * Double.random(in: 1.0...5.0)
            let totalBTC = Double.random(in: 0.005...0.05)
            let txCount = Int.random(in: 40...2000)
            
            // Mining time increases with index, but we'll sort them later
            let miningTime = i * 10
            
            sampleBlocks.append(
                PendingBlock(
                    blockFeeRate: feeRate,
                    feeRange: (feeRate, maxFeeRate),
                    totalBTC: totalBTC,
                    txCount: txCount,
                    minutesUntilMining: miningTime
                )
            )
        }
        
        // Sort by minutes until mining (ascending)
        return sampleBlocks.sorted(by: { $0.minutesUntilMining < $1.minutesUntilMining })
    }
}

// Main view now defined separately (not inside the view model)
struct BlocksView: View {
    @StateObject private var viewModel = BlocksViewModel()
    
    // State variables to track selected block and presentation state
    @State private var selectedBlock: Block?
    @State private var selectedPendingBlock: PendingBlock?
    @State private var isBlockDetailPresented = false
    
    // Use a continuous value for flickering with a wider range for more visibility
    @State private var flickerIntensity: Double = 1.0
    // Timer for controlling the animation
    @State private var timer: Timer? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading block data...")
                        .padding()
                        .foregroundColor(Color.white)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Pending blocks (mempool)
                    pendingBlocksSection
                    
                    // Recent mined blocks
                    recentBlocksSection
                }
            }
            .padding()
        }
        .navigationTitle("Bitcoin Blocks")
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
            
            // Start the manual timer-based animation
            startManualFlickeringAnimation()
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
        .background(Color.mempoolBackground)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isBlockDetailPresented, onDismiss: {
            selectedBlock = nil
            selectedPendingBlock = nil
        }) {
            if let block = selectedBlock {
                BlockDetailView(blockId: block.id, blockHeight: block.height)
            } else if let pendingBlock = selectedPendingBlock {
                pendingBlockDetailView(for: pendingBlock)
            }
        }
    }
    
    // Use a timer-based approach for more reliable animation
    private func startManualFlickeringAnimation() {
        // Cancel any existing timer
        timer?.invalidate()
        
        // Create a new timer that updates the intensity value
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            // Calculate the flickering value using a sine wave for smooth transition
            let time = Date().timeIntervalSince1970
            // This creates a value that oscillates between 0.6 and 0.9 over a 4 second period
            let newIntensity = 0.75 + 0.15 * sin(2.0 * .pi * time / 4.0)
            
            // Update the intensity on the main thread
            DispatchQueue.main.async {
                self.flickerIntensity = newIntensity
            }
        }
    }
    
    // MARK: - UI Components
    
    // Pending blocks section
    private var pendingBlocksSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pending Blocks")
                    .font(.headline)
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Show block count
                if !viewModel.pendingBlocks.isEmpty {
                    Text("\(viewModel.pendingBlocks.count) blocks")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    if viewModel.pendingBlocks.isEmpty {
                        Text("No pending blocks data available")
                            .italic()
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(width: 180, height: 170)
                            .background(Color(.systemGray6).opacity(0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        // Show all blocks in order from left to right
                        // The blocks are already sorted by minutesUntilMining
                        ForEach(viewModel.pendingBlocks) { block in
                            PendingBlockCard(
                                block: block,
                                selectedPendingBlock: $selectedPendingBlock,
                                isBlockDetailPresented: $isBlockDetailPresented,
                                flickerIntensity: $flickerIntensity
                            )
                        }
                    }
                }
                .padding(.bottom, 4)
                .padding(.horizontal, 4) // Add padding at the ends for better scrolling
            }
            // Make the scroll view taller to accommodate more blocks
            .frame(height: 180)
        }
        .padding()
        .background(Color.mempoolBackground.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Recent blocks section
    private var recentBlocksSection: some View {
        VStack(spacing: 16) {
            Text("Recent Blocks")
                .font(.headline)
                .foregroundColor(Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recentBlocks) { block in
                        recentBlockCard(for: block)
                    }
                    
                    if viewModel.recentBlocks.isEmpty {
                        Text("No block data available")
                            .italic()
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(width: 180, height: 140)
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
    
    // UPDATED Recent block card component - Now matches the dashboard design
    private func recentBlockCard(for block: Block) -> some View {
        // Card dimensions - slightly wider to allow for better text display
        let width: CGFloat = 160
        let height: CGFloat = 160
        
        return ZStack {
            // Shadow/background layer to create subtle 3D effect
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
                .frame(width: width, height: height)
                .offset(x: 3, y: 3)
            
            // Main content layer with purple gradient
            VStack(alignment: .leading, spacing: 3) {
                // Block height in cyan with commas
                Text(formatBlockHeight(block.height))
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
                    .padding(.top, 2)
                
                // Transactions count
                Text("\(formatNumber(block.txCount)) transactions")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                
                // Time ago
                Text(timeAgo(timestamp: block.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Mining pool name with circle indicator
                HStack {
                    Circle()
                        .fill(getMiningPoolColor(for: block.height))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(getMiningPoolInitial(for: block.height))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text(getPoolName(for: block.height))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 6) // Reduced padding
            .padding(.vertical, 8)
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
            .cornerRadius(16)
        }
        .frame(width: width, height: height)
        .onTapGesture {
            selectedBlock = block
            isBlockDetailPresented = true
        }
    }
    
    // Format block height with commas
    private func formatBlockHeight(_ height: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: height)) ?? "\(height)"
    }
    
    // Format numbers with commas
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    // Get mining pool initial for circle icon
    private func getMiningPoolInitial(for height: Int) -> String {
        let poolName = getPoolName(for: height)
        return String(poolName.prefix(1))
    }
    
    // Get mining pool color for icon
    private func getMiningPoolColor(for height: Int) -> Color {
        let poolName = getPoolName(for: height)
        switch poolName {
        case "F2Pool": return Color.blue
        case "MARA Pool": return Color.purple
        case "AntPool": return Color.green
        case "Foundry USA": return Color.orange
        case "SpiderPool": return Color.yellow
        default: return Color.gray
        }
    }
    
    // Estimate fee rate based on block height
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
    
    // MARK: - Helper Functions
    
    // Convert timestamp to "time ago" string
    private func timeAgo(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Get pool name based on block height (demo implementation)
    private func getPoolName(for height: Int) -> String {
        let pools = ["AntPool", "Binance Pool", "F2Pool", "Foundry USA", "ViaBTC", "Braiins Pool"]
        let index = height % pools.count
        return pools[index]
    }
    
    // View for pending block details
    private func pendingBlockDetailView(for block: PendingBlock) -> some View {
        NavigationView {
            ZStack {
                Color.mempoolBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header section
                        VStack(spacing: 8) {
                            Text("Pending Block")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("This block has not been mined yet")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.vertical)
                        
                        // Block details section
                        VStack(spacing: 16) {
                            Text("Estimated Information")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Group {
                                // Fee Rate
                                infoRow(title: "Fee Rate", value: block.formattedFeeRate)
                                
                                // Fee Range
                                infoRow(title: "Fee Range", value: block.formattedFeeRange)
                                
                                // Transaction Count
                                infoRow(title: "Transactions", value: "\(block.txCount)")
                                
                                // Total BTC
                                infoRow(title: "Total Fees", value: block.formattedBTC)
                                
                                // Time Estimate
                                infoRow(title: "ETA", value: "~\(block.minutesUntilMining) minutes")
                            }
                        }
                        .padding()
                        .background(Color.mempoolBackground.opacity(0.3))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Fee explanation section
                        VStack(spacing: 16) {
                            Text("What does this mean?")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("This block is estimated to be mined in approximately \(block.minutesUntilMining) minutes. It currently contains about \(block.txCount) transactions with a median fee rate of \(block.formattedFeeRate).")
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Color.mempoolBackground.opacity(0.3))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.mempoolPrimary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Pending Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isBlockDetailPresented = false
                    }
                    .foregroundColor(Color.mempoolPrimary)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // Helper function to create an info row
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// PendingBlockCard also moved outside as a separate view struct
struct PendingBlockCard: View {
    let block: PendingBlock
    @Binding var selectedPendingBlock: PendingBlock?
    @Binding var isBlockDetailPresented: Bool
    @Binding var flickerIntensity: Double
    
    // Define a more dramatic gradient that will be more visible
    private var gradientForIntensity: LinearGradient {
        // Calculate colors based on current intensity
        let topColor = Color(
            red: 0.45 * flickerIntensity,
            green: 0.65 * flickerIntensity,
            blue: 0.2 * flickerIntensity
        )
        
        let bottomColor = Color(
            red: 0.35 * flickerIntensity,
            green: 0.55 * flickerIntensity,
            blue: 0.1 * flickerIntensity
        )
        
        return LinearGradient(
            gradient: Gradient(colors: [topColor, bottomColor]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        // Card dimensions - matching screenshot
        let width: CGFloat = 160
        let height: CGFloat = 160
        
        ZStack {
            // 3D shadow effect
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .frame(width: width, height: height)
                .offset(x: 6, y: 6)
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Fee Rate
                Text(block.formattedFeeRate)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // Fee Range in yellow
                Text(block.formattedFeeRange)
                    .font(.system(size: 12))
                    .foregroundColor(Color.yellow)
                
                // BTC Amount
                Text(block.formattedBTC)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 3)
                
                // Transaction Count
                Text("\(block.txCount) transactions")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                
                // Time Estimate - matching screenshot
                Text("In ~\(block.minutesUntilMining) minutes")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.top, 3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(width: width, height: height)
            .background(gradientForIntensity)
            .cornerRadius(12)
        }
        .frame(width: width, height: height)
        .onTapGesture {
            selectedPendingBlock = block
            isBlockDetailPresented = true
        }
    }
}
