//
//  SearchView.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import SwiftUI

// Defines the possible search result types
enum SearchResultType {
    case transaction
    case address
    case none
}

// ViewModel to handle search functionality and data
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var resultType: SearchResultType = .none
    @Published var transaction: Transaction?
    @Published var addressInfo: AddressInfo?
    @Published var addressUtxos: [AddressUtxo] = []
    @Published var addressTransactions: [Transaction] = []
    @Published var errorMessage: String?
    
    private let apiClient = MempoolAPIClient.shared
    
    // Main search function - determines type of search and executes it
    func search() {
        guard !searchText.isEmpty else { return }
        
        reset()
        isSearching = true
        
        if isTransactionID(searchText) {
            searchTransaction()
        } else if isBitcoinAddress(searchText) {
            searchAddress()
        } else {
            isSearching = false
            errorMessage = "Invalid input format. Please enter a valid transaction ID or Bitcoin address."
        }
    }
    
    // Resets all search results
    private func reset() {
        errorMessage = nil
        transaction = nil
        addressInfo = nil
        addressUtxos = []
        addressTransactions = []
        resultType = .none
    }
    
    // Validates if input is a transaction ID
    private func isTransactionID(_ input: String) -> Bool {
        let hexRegex = "^[0-9a-fA-F]{64}$"
        return input.range(of: hexRegex, options: .regularExpression) != nil
    }
    
    // Validates if input is a Bitcoin address
    private func isBitcoinAddress(_ input: String) -> Bool {
        if input.hasPrefix("1") && input.count >= 26 && input.count <= 34 { return true }
        if input.hasPrefix("3") && input.count >= 26 && input.count <= 34 { return true }
        if input.hasPrefix("bc1") && input.count >= 42 && input.count <= 62 { return true }
        return false
    }
    
    // Fetches transaction data from API
    private func searchTransaction() {
        Task {
            do {
                // Debug the API response
                await MempoolAPIClient.shared.debugAPIResponse(endpoint: "/tx/\(searchText)")
                
                // Fetch transaction details
                let tx = try await apiClient.fetchTransaction(id: searchText)
                
                DispatchQueue.main.async {
                    self.transaction = tx
                    self.resultType = .transaction
                    self.isSearching = false
                }
            } catch {
                print("Transaction search error: \(error)")
                
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching transaction: \(error.localizedDescription)"
                    self.isSearching = false
                }
            }
        }
    }
    
    // Fetches address data from API
    private func searchAddress() {
        Task {
            do {
                // Debug the API response
                await MempoolAPIClient.shared.debugAPIResponse(endpoint: "/address/\(searchText)")
                
                // Fetch address info
                let info = try await apiClient.fetchAddressInfo(address: searchText)
                
                // Fetch UTXOs and transactions in parallel
                async let utxosTask = apiClient.fetchAddressUtxos(address: searchText)
                async let txsTask = apiClient.fetchAddressTransactions(address: searchText, limit: 10)
                
                let (utxos, txs) = try await (utxosTask, txsTask)
                
                DispatchQueue.main.async {
                    self.addressInfo = info
                    self.addressUtxos = utxos
                    self.addressTransactions = txs
                    self.resultType = .address
                    self.isSearching = false
                }
            } catch {
                print("Address search error: \(error)")
                
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching address data: \(error.localizedDescription)"
                    self.isSearching = false
                }
            }
        }
    }
}

// MARK: - SearchView (Top-level struct, accessible from ContentView)
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // Content area
            ScrollView {
                if viewModel.isSearching {
                    ProgressView("Searching...")
                        .padding(.top, 40)
                        .foregroundColor(.white)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    switch viewModel.resultType {
                    case .transaction:
                        if let tx = viewModel.transaction {
                            transactionDetailView(for: tx)
                        }
                    case .address:
                        if let address = viewModel.addressInfo {
                            addressDetailView(for: address)
                        }
                    case .none:
                        emptyStateView
                    }
                }
            }
            .background(Color.mempoolBackground)
        }
        .navigationTitle("Search")
        .background(Color.mempoolBackground)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - UI Components
    
    // Search bar component
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter transaction ID or address", text: $viewModel.searchText)
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.search()
                    }
                
                Button(action: {
                    viewModel.search()
                }) {
                    Text("Search")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.mempoolPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            // Search result type indicator
            if viewModel.resultType != .none && !viewModel.isSearching {
                HStack {
                    Image(systemName: viewModel.resultType == .transaction ? "doc.text" : "person.crop.circle")
                        .foregroundColor(.mempoolPrimary)
                    
                    Text(viewModel.resultType == .transaction ? "Transaction" : "Address")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
        }
    }
    
    // Empty state component for initial screen
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(Color.mempoolPrimary.opacity(0.7))
            
            Text("Search the Bitcoin Blockchain")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("You can search for:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.text")
                        .foregroundColor(Color.mempoolPrimary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading) {
                        Text("Transaction IDs")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("64-character hexadecimal string")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(Color.mempoolPrimary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading) {
                        Text("Bitcoin Addresses")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("Starting with 1, 3, or bc1")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    // Error view for displaying error messages
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("Search Error")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .padding()
                .background(Color(.systemGray6).opacity(0.15))
                .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Transaction Detail View
    
    // View for displaying transaction details
    private func transactionDetailView(for tx: Transaction) -> some View {
        VStack(spacing: 16) {
            // Transaction header with ID and status
            VStack(spacing: 12) {
                Text("Transaction")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(tx.id)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(Color.mempoolPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Transaction status indicator with pill design
                HStack {
                    Spacer()
                    
                    if let statusObj = tx.statusObject, statusObj.confirmed == true {
                        // Confirmed transaction with green pill design
                        HStack {
                            if let confirmations = tx.confirmations, confirmations > 0 {
                                Text("\(confirmations) confirmation\(confirmations > 1 ? "s" : "")")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            } else {
                                Text("Confirmed")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                        }
                    } else {
                        // Unconfirmed transaction with red pill design
                        Text("Unconfirmed")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Copy button
                    Button(action: {
                        UIPasteboard.general.string = tx.id
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Color.mempoolPrimary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
            
            // Transaction technical details
            VStack(spacing: 12) {
                Text("Details")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                infoRow(title: "Size", value: "\(tx.size) bytes")
                infoRow(title: "Weight", value: "\(tx.vsize * 4) WU")
                infoRow(title: "Virtual Size", value: "\(tx.vsize) vB")
                HStack {
                    Text("Fee")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatBitcoin(tx.fee))
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        // Add USD fee calculation
                        let usdFee = tx.fee * MempoolAPIClient.shared.currentBitcoinPrice
                        Text("$\(formatNumberWithCommas(usdFee))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
                infoRow(title: "Fee Rate", value: formatFeeRate(tx.fee, vsize: tx.vsize))
                infoRow(title: "Received", value: formatDate(tx.timestamp ?? Int(Date().timeIntervalSince1970)))
                infoRow(title: "Status", value: tx.status ?? "Unknown")
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
            
            // Inputs and Outputs section
            transactionIOSection(for: tx)
        }
        .padding()
    }
    
    // Transaction inputs and outputs section
    private func transactionIOSection(for tx: Transaction) -> some View {
        VStack(spacing: 12) {
            // Inputs header
            HStack {
                Text("Inputs")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
                
                // Total input amount
                Text(formatBitcoin(calculateTotalInputs(tx)))
                    .font(.subheadline)
                    .foregroundColor(Color.white)
            }
            
            // Input list
            ForEach(Array(zip(tx.vin ?? [], 0..<(tx.vin?.count ?? 0))), id: \.1) { pair in
                let (input, index) = pair
                inputRow(for: input)
            }
            
            // Separator
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 8)
            
            // Outputs header
            HStack {
                Text("Outputs")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
                
                // Total output amount
                Text(formatBitcoin(calculateTotalOutputs(tx)))
                    .font(.subheadline)
                    .foregroundColor(Color.white)
            }
            
            // Output list
            ForEach(tx.vout ?? [], id: \.scriptpubkey_address) { output in
                outputRow(for: output)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
    
    // Single transaction input row
    private func inputRow(for input: TransactionInput) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let address = input.prevout?.scriptpubkey_address {
                HStack {
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.red)
                    
                    Text(formatAddress(address))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let value = input.prevout?.value {
                        Text(formatSatoshis(value))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } else {
                Text("Coinbase")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
    }
    
    // Single transaction output row
    private func outputRow(for output: TransactionOutput) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.down.left")
                    .foregroundColor(.green)
                
                Text(formatAddress(output.scriptpubkey_address ?? "Unknown"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatSatoshis(output.value))
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
    }
    
    // MARK: - Address Detail View
    
    // View for displaying address details
    private func addressDetailView(for address: AddressInfo) -> some View {
        VStack(spacing: 16) {
            // Address header with ID and copy button
            VStack(spacing: 12) {
                Text("Address")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(address.address)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(Color.mempoolPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Copy button
                HStack {
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = address.address
                    }) {
                        HStack {
                            Text("Copy Address")
                                .font(.caption)
                            
                            Image(systemName: "doc.on.doc")
                        }
                        .foregroundColor(Color.mempoolPrimary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.mempoolPrimary.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
            
            // Balance information
            VStack(spacing: 12) {
                Text("Balance")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Received:")
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.7))
                        
                        Text(formatSatoshis(address.chainStats.funded_txo_sum))
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Spent:")
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.7))
                        
                        Text(formatSatoshis(address.chainStats.spent_txo_sum))
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                HStack {
                    Text("Final Balance:")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                    
                    Spacer()
                    
                    // Calculate the balance
                    let balanceSats = address.chainStats.funded_txo_sum - address.chainStats.spent_txo_sum
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatSatoshis(balanceSats))
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        // Calculate and display USD value using live Bitcoin price
                        let btcBalance = Double(balanceSats) / 100_000_000.0
                        let currentPrice = MempoolAPIClient.shared.currentBitcoinPrice
                        let usdValue = btcBalance.isFinite ? btcBalance * currentPrice : 0
                        Text("$\(formatNumberWithCommas(usdValue))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
            
            // UTXOs section
            utxoSection
            
            // Recent transactions section
            transactionHistorySection
        }
        .padding()
    }
    
    // Unspent transaction outputs section
    private var utxoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Unspent Outputs (\(viewModel.addressUtxos.count))")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
            }
            
            if viewModel.addressUtxos.isEmpty {
                Text("No unspent outputs")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            } else {
                ForEach(viewModel.addressUtxos, id: \.txid) { utxo in
                    utxoRow(for: utxo)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
    
    // Transaction history section
    private var transactionHistorySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Transactions (\(viewModel.addressTransactions.count))")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
            }
            
            if viewModel.addressTransactions.isEmpty {
                Text("No transactions found")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            } else {
                ForEach(viewModel.addressTransactions) { tx in
                    transactionHistoryRow(for: tx)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
    
    // Single UTXO row
    private func utxoRow(for utxo: AddressUtxo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatShortTxid(utxo.txid))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color.mempoolPrimary)
                
                Spacer()
                
                Text(formatSatoshis(utxo.value))
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Output #\(utxo.vout)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("Confirmations: \(utxo.status.confirmed ? "\(utxo.status.block_height ?? 0)" : "Unconfirmed")")
                    .font(.caption)
                    .foregroundColor(utxo.status.confirmed ? .green : .yellow)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    // Transaction history row
    private func transactionHistoryRow(for tx: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatShortTxid(tx.id))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color.mempoolPrimary)
                
                Spacer()
                
                if let timestamp = tx.timestamp {
                    Text(formatRelativeTime(timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            HStack {
                // Determine transaction direction (simplified)
                let direction = getTransactionDirection(tx)
                
                Image(systemName: direction == "incoming" ? "arrow.down.left" : "arrow.up.right")
                    .foregroundColor(direction == "incoming" ? .green : .red)
                
                Text(direction == "incoming" ? "Received" : "Sent")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                // Show amount
                Text(formatSatoshis(Int(tx.value)))
                    .font(.subheadline)
                    .foregroundColor(direction == "incoming" ? .green : .red)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Formatting Helpers
    
    // Generic info row for key-value pairs
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
    
    // Format address with ellipsis in the middle
    private func formatAddress(_ address: String) -> String {
        if address.count > 20 {
            let start = address.prefix(10)
            let end = address.suffix(10)
            return "\(start)...\(end)"
        }
        return address
    }
    
    // Format Bitcoin amount to 8 decimal places
    private func formatBitcoin(_ value: Double) -> String {
        return String(format: "%.8f BTC", value)
    }
    
    // Format satoshis to BTC or sats depending on amount
    private func formatSatoshis(_ value: Int) -> String {
        let btcValue = Double(value) / 100_000_000.0
        return String(format: "%.8f BTC", btcValue)
    }
    
    // Calculate fee rate in sat/vB
    private func formatFeeRate(_ fee: Double, vsize: Int) -> String {
        // Prevent division by zero and NaN results
        guard vsize > 0 && !fee.isNaN && fee.isFinite else {
            return "0.00 sat/vB"
        }
        
        // Convert from BTC to satoshis and calculate per vByte
        let feeInSatoshis = fee * 100_000_000
        let satPerVbyte = feeInSatoshis / Double(vsize)
        
        // Check for valid result before formatting
        guard !satPerVbyte.isNaN && satPerVbyte.isFinite else {
            return "0.00 sat/vB"
        }
        
        return String(format: "%.2f sat/vB", satPerVbyte)
    }
    
    // Format timestamp to readable date
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // Format timestamp to relative time
    private func formatRelativeTime(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Format transaction ID with ellipsis
    private func formatShortTxid(_ txid: String) -> String {
        if txid.count > 16 {
            let prefix = String(txid.prefix(8))
            let suffix = String(txid.suffix(8))
            return "\(prefix)...\(suffix)"
        }
        return txid
    }
    
    // Calculate total input value for transaction
    private func calculateTotalInputs(_ tx: Transaction) -> Double {
        let inputsSum = tx.vin?.reduce(0) { sum, input in
            sum + (input.prevout?.value ?? 0)
        } ?? 0
        
        return Double(inputsSum) / 100_000_000.0
    }
    
    // Calculate total output value for transaction
    private func calculateTotalOutputs(_ tx: Transaction) -> Double {
        let outputsSum = tx.vout?.reduce(0) { sum, output in
            sum + output.value
        } ?? 0
        
        return Double(outputsSum) / 100_000_000.0
    }
    
    // Determine transaction direction (simplified)
    private func getTransactionDirection(_ tx: Transaction) -> String {
        // In a real implementation, compare with the viewed address
        // For demo purposes, just use random values
        let random = Int.random(in: 0...1)
        return random == 0 ? "incoming" : "outgoing"
    }
    
    private func formatNumberWithCommas(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
