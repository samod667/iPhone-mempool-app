import Foundation

// Define BitcoinNetwork here if it's not imported from elsewhere
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

class MempoolAPIClient {
    // Changed from let to var to allow updating
    private var baseURL = "https://mempool.space/api"
    internal let session: URLSession
    
    // Bitcoin price tracking
    private var _currentBitcoinPrice: Double = 65000.0  // Default fallback value
    private var lastPriceUpdate: Date? = nil
    private let priceUpdateInterval: TimeInterval = 300 // 5 minutes
    
    var currentBitcoinPrice: Double {
        return _currentBitcoinPrice
    }
    
    // Singleton instance
    static let shared = MempoolAPIClient()
    
    // Private initializer for singleton
    private init() {
        // Create a custom URLSessionConfiguration with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0 // 30 seconds timeout
        configuration.timeoutIntervalForResource = 60.0 // 60 seconds resource timeout
        
        self.session = URLSession(configuration: configuration)
        
        // Check for saved endpoint in UserDefaults
        if let savedEndpoint = UserDefaults.standard.string(forKey: "apiEndpoint"),
           !savedEndpoint.isEmpty {
            self.baseURL = savedEndpoint
            print("Using saved API endpoint: \(savedEndpoint)")
        }
        
        // Check for network setting
        if let networkValue = UserDefaults.standard.string(forKey: "selectedNetwork"),
           let network = BitcoinNetwork(rawValue: networkValue),
           !UserDefaults.standard.bool(forKey: "useCustomEndpoint") {
            self.baseURL = network.endpoint
            print("Using network endpoint: \(network.endpoint)")
        }
        
        // Fetch initial bitcoin price
        refreshBitcoinPrice()
    }
    
    // New method to update the base URL
    func updateBaseURL(to newURL: String) {
        guard !newURL.isEmpty else { return }
        
        print("Updating API base URL to: \(newURL)")
        self.baseURL = newURL
    }
    
    // Fetch the current Bitcoin price
    func fetchBitcoinPrice() async {
        // Only update if more than 5 minutes since last update or no previous update
        if let lastUpdate = lastPriceUpdate, Date().timeIntervalSince(lastUpdate) < priceUpdateInterval {
            return
        }
        
        do {
            // Use the mempool.space price endpoint
            let endpoint = "/v1/prices"
            let (data, _) = try await fetchData(from: endpoint)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let usd = json["USD"] as? Double, usd > 0 {
                DispatchQueue.main.async {
                    self._currentBitcoinPrice = usd
                    self.lastPriceUpdate = Date()
                }
                print("Updated Bitcoin price: $\(usd)")
            }
        } catch {
            print("Error fetching Bitcoin price: \(error)")
            // Keep using the last known price
        }
    }
    
    // Refresh Bitcoin price
    func refreshBitcoinPrice() {
        Task {
            await fetchBitcoinPrice()
        }
    }
    
    // MARK: - Caching Support
    
    // Add a method to fetch data with caching
    func fetchDataWithCache(from endpoint: String) async throws -> Data {
        // Create a unique cache key based on the endpoint
        let cacheKey = endpoint.replacingOccurrences(of: "/", with: "_")
        
        // Check if we have valid cached data
        if let cachedData = CacheManager.shared.loadFromCache(for: cacheKey) {
            print("Using cached data for: \(endpoint)")
            return cachedData
        }
        
        // If no cache, fetch the data normally
        let (data, _) = try await fetchData(from: endpoint)
        
        // Cache the response
        CacheManager.shared.saveToCache(data: data, for: cacheKey)
        
        return data
    }
    
    // Fetch mempool stats with caching
    func fetchMempoolStatsWithCache() async throws -> MempoolStats {
        let endpoint = "/mempool"
        
        do {
            let data = try await fetchDataWithCache(from: endpoint)
            
            let decoder = JSONDecoder()
            let stats = try decoder.decode(MempoolStats.self, from: data)
            print("Successfully decoded MempoolStats: \(stats)")
            
            // Check if we should send a notification about mempool congestion
            let threshold = 15000 // Arbitrary threshold for demonstration
            if stats.mempoolSize > threshold && NotificationsManager.shared.areNotificationsEnabled {
                // Calculate average fee rate
                let avgFeeRate = Double(stats.totalFeeInSatoshis) / Double(stats.vsize)
                
                // Send a notification
                NotificationsManager.shared.notifyMempoolCongestion(
                    txCount: stats.mempoolSize,
                    avgFeeRate: avgFeeRate
                )
            }
            
            return stats
        } catch {
            print("Error fetching mempool stats: \(error)")
            throw error
        }
    }
    
    // Update fetchRecentBlocks to use caching
    func fetchRecentBlocksWithCache(limit: Int = 10) async throws -> [Block] {
        let endpoint = "/v1/blocks"
        
        do {
            let data = try await fetchDataWithCache(from: endpoint)
            
            let decoder = JSONDecoder()
            let blocks = try decoder.decode([Block].self, from: data)
            print("Successfully decoded \(blocks.count) blocks")
            
            // If we have a latest block and notifications are enabled, send notification
            if let latestBlock = blocks.first, NotificationsManager.shared.areNotificationsEnabled {
                // Store the last notified block height
                let lastNotifiedHeight = UserDefaults.standard.integer(forKey: "lastNotifiedBlockHeight")
                
                // Only notify if this is a new block
                if latestBlock.height > lastNotifiedHeight {
                    NotificationsManager.shared.notifyNewBlock(height: latestBlock.height)
                    
                    // Update the last notified height
                    UserDefaults.standard.set(latestBlock.height, forKey: "lastNotifiedBlockHeight")
                }
            }
            
            return blocks
        } catch {
            print("Error fetching blocks: \(error)")
            throw error
        }
    }
    
    // Update fetchRecommendedFees to use caching
    func fetchRecommendedFeesWithCache() async throws -> [String: Double] {
        let endpoint = "/v1/fees/recommended"
        
        do {
            let data = try await fetchDataWithCache(from: endpoint)
            
            let fees = try JSONDecoder().decode([String: Double].self, from: data)
            print("Successfully decoded fees: \(fees)")
            
            // Check if we should notify about significant fee changes
            if NotificationsManager.shared.areNotificationsEnabled {
                if let fastestFee = fees["fastestFee"] {
                    // Get the previously recorded fee rate
                    let previousFee = UserDefaults.standard.double(forKey: "previousFastestFee")
                    
                    // Calculate percent change
                    if previousFee > 0 {
                        let percentChange = ((fastestFee - previousFee) / previousFee) * 100
                        
                        // Only notify on significant changes (e.g., > 20%)
                        if abs(percentChange) > 20 {
                            NotificationsManager.shared.notifyFeeRateChange(
                                newRate: fastestFee,
                                changePercentage: percentChange
                            )
                        }
                    }
                    
                    // Store the current fee for future comparison
                    UserDefaults.standard.set(fastestFee, forKey: "previousFastestFee")
                }
            }
            
            return fees
        } catch {
            print("Error fetching fees: \(error)")
            throw error
        }
    }
    
    // MARK: - Mempool Statistics
    
    // Fetch current mempool statistics
    func fetchMempoolStats() async throws -> MempoolStats {
        let endpoint = "/mempool"
        let url = try buildURL(with: endpoint)
        
        print("Fetching mempool stats from: \(url)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Print the raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response: \(jsonString.prefix(200))...") // Print just first 200 chars to keep logs manageable
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid HTTP response")
                throw URLError(.badServerResponse)
            }
            
            print("Status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Bad status code: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            do {
                let stats = try decoder.decode(MempoolStats.self, from: data)
                print("Successfully decoded MempoolStats: \(stats)")
                return stats
            } catch {
                print("JSON decoding error: \(error)")
                print("JSON structure mismatch. Attempting to print the JSON structure:")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("JSON keys at root level: \(json.keys)")
                    for (key, value) in json {
                        print("Key: \(key), Type: \(type(of: value))")
                    }
                }
                throw error
            }
        } catch {
            print("Error fetching mempool stats: \(error)")
            throw error
        }
    }
    
    // MARK: - Blockchain Information
    
    // Fetch current blockchain information
    func fetchBlockchainInfo() async throws -> BlockchainInfo {
        print("Fetching blockchain info...")
        
        // Get the current block height
        let heightEndpoint = "/blocks/tip/height"
        let heightURL = try buildURL(with: heightEndpoint)
        
        print("Fetching block height from: \(heightURL)")
        
        let (heightData, heightResponse) = try await session.data(from: heightURL)
        
        guard let heightHttpResponse = heightResponse as? HTTPURLResponse,
              (200...299).contains(heightHttpResponse.statusCode) else {
            print("Bad response for block height")
            throw URLError(.badServerResponse)
        }
        
        let heightString = String(data: heightData, encoding: .utf8) ?? "0"
        let height = Int(heightString) ?? 0
        
        print("Current block height: \(height)")
        
        // Get the block hash
        let hashEndpoint = "/block-height/\(height)"
        let hashURL = try buildURL(with: hashEndpoint)
        
        print("Fetching block hash from: \(hashURL)")
        
        let (hashData, hashResponse) = try await session.data(from: hashURL)
        
        guard let hashHttpResponse = hashResponse as? HTTPURLResponse,
              (200...299).contains(hashHttpResponse.statusCode) else {
            print("Bad response for block hash")
            throw URLError(.badServerResponse)
        }
        
        let blockHash = String(data: hashData, encoding: .utf8) ?? ""
        
        print("Block hash: \(blockHash)")
        
        // Get the block info
        let blockEndpoint = "/block/\(blockHash)"
        let blockURL = try buildURL(with: blockEndpoint)
        
        print("Fetching block info from: \(blockURL)")
        
        let (blockData, blockResponse) = try await session.data(from: blockURL)
        
        guard let blockHttpResponse = blockResponse as? HTTPURLResponse,
              (200...299).contains(blockHttpResponse.statusCode) else {
            print("Bad response for block info")
            throw URLError(.badServerResponse)
        }
        
        // Try to decode the data
        do {
            if let json = try? JSONSerialization.jsonObject(with: blockData) as? [String: Any] {
                print("Block data keys: \(json.keys)")
                
                // Extract difficulty from the block data if available
                let difficulty = json["difficulty"] as? Double ?? 0.0
                
                print("Block difficulty: \(difficulty)")
                
                return BlockchainInfo(height: height, difficulty: difficulty, bestBlockHash: blockHash)
            } else {
                print("Failed to parse block data as JSON")
                return BlockchainInfo(height: height, difficulty: 0.0, bestBlockHash: blockHash)
            }
        }
    }
    
    // MARK: - Transactions
    
    // Search for a transaction by its ID
    func fetchTransaction(id: String) async throws -> Transaction {
        let endpoint = "/tx/\(id)"
        let url = try buildURL(with: endpoint)
        
        print("Fetching transaction data from: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Bad response for transaction request")
            throw URLError(.badServerResponse)
        }
        
        do {
            let transaction = try JSONDecoder().decode(Transaction.self, from: data)
            print("Successfully decoded transaction: \(transaction.id)")
            return transaction
        } catch {
            print("Error decoding transaction: \(error)")
            throw error
        }
    }
    
    // Get recent transactions in the mempool
    func fetchRecentTransactions(limit: Int = 10) async throws -> [Transaction] {
        let endpoint = "/mempool/recent?limit=\(limit)"
        let url = try buildURL(with: endpoint)
        
        print("Fetching recent transactions from: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Bad response for recent transactions request")
            throw URLError(.badServerResponse)
        }
        
        do {
            let transactions = try JSONDecoder().decode([Transaction].self, from: data)
            print("Successfully decoded \(transactions.count) transactions")
            return transactions
        } catch {
            print("Error decoding transactions: \(error)")
            
            // Try to analyze the actual JSON structure
            if let json = try? JSONSerialization.jsonObject(with: data) {
                print("JSON structure: \(type(of: json))")
                
                if let arrayJSON = json as? [[String: Any]], !arrayJSON.isEmpty {
                    print("First item keys: \(arrayJSON[0].keys)")
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Blocks
    
    // Get recent blocks
    func fetchRecentBlocks(limit: Int = 10) async throws -> [Block] {
        // Use the simple endpoint that returns most recent blocks
        let endpoint = "/v1/blocks"  // This is the correct v1 API endpoint
        let url = try buildURL(with: endpoint)
        
        print("Fetching recent blocks from: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Bad response for recent blocks request")
            throw URLError(.badServerResponse)
        }
        
        do {
            // For debugging, print the raw data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw blocks response (first 300 chars): \(String(jsonString.prefix(300)))")
            }
            
            let decoder = JSONDecoder()
            let blocks = try decoder.decode([Block].self, from: data)
            print("Successfully decoded \(blocks.count) blocks")
            return blocks
        } catch {
            print("Error decoding blocks: \(error)")
            throw error
        }
    }
    
    // MARK: - Fees
    
    // Get recommended fee rates
    func fetchRecommendedFees() async throws -> [String: Double] {
        let endpoint = "/v1/fees/recommended"
        let url = try buildURL(with: endpoint)
        
        print("Fetching recommended fees from: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Bad response for fee request")
            throw URLError(.badServerResponse)
        }
        
        do {
            let fees = try JSONDecoder().decode([String: Double].self, from: data)
            print("Successfully decoded fees: \(fees)")
            return fees
        } catch {
            print("Error decoding fees: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    // Build URL with the given endpoint
    internal func buildURL(with endpoint: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        return url
    }
    
    internal func fetchData(from endpoint: String) async throws -> (Data, URLResponse) {
        let url = try buildURL(with: endpoint)
        return try await session.data(from: url)
    }
    
    // Handle HTTP responses
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Extension for MempoolAPIClient with Address endpoints

extension MempoolAPIClient {
    
    // MARK: - Address Information
    
    /// Fetch information about a Bitcoin address
    /// - Parameter address: The Bitcoin address to query
    /// - Returns: Address information including balance and transaction counts
    func fetchAddressInfo(address: String) async throws -> AddressInfo {
        let endpoint = "/address/\(address)"
        
        do {
            let (data, _) = try await fetchData(from: endpoint)
            print("Received \(data.count) bytes for address \(address)")
            
            // Try to print the first part of the response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Address response sample: \(jsonString.prefix(200))")
            }
            
            let decoder = JSONDecoder()
            let addressInfo = try decoder.decode(AddressInfo.self, from: data)
            print("Successfully decoded address info: \(addressInfo.address)")
            return addressInfo
        } catch {
            print("Error decoding address info: \(error)")
            // Print detailed decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("Type mismatch: \(type), path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: \(type), path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    /// Fetch UTXOs (unspent transaction outputs) for a Bitcoin address
    /// - Parameter address: The Bitcoin address to query
    /// - Returns: Array of unspent outputs for the address
    func fetchAddressUtxos(address: String) async throws -> [AddressUtxo] {
        let endpoint = "/address/\(address)/utxo"
        
        do {
            let (data, _) = try await fetchData(from: endpoint)
            
            do {
                let utxos = try JSONDecoder().decode([AddressUtxo].self, from: data)
                print("Successfully decoded \(utxos.count) UTXOs for address")
                return utxos
            } catch {
                print("Error decoding address UTXOs: \(error)")
                throw error
            }
        } catch {
            print("Error fetching address UTXOs: \(error)")
            throw error
        }
    }
    
    /// Fetch recent transactions for a Bitcoin address
    /// - Parameters:
    ///   - address: The Bitcoin address to query
    ///   - limit: Maximum number of transactions to return (default: 10)
    /// - Returns: Array of transactions for the address
    func fetchAddressTransactions(address: String, limit: Int = 10) async throws -> [Transaction] {
        let endpoint = "/address/\(address)/txs/chain"
        
        do {
            let (data, _) = try await fetchData(from: endpoint)
            
            do {
                var transactions = try JSONDecoder().decode([Transaction].self, from: data)
                
                // Limit the number of transactions if needed
                if transactions.count > limit {
                    transactions = Array(transactions.prefix(limit))
                }
                
                print("Successfully decoded \(transactions.count) transactions for address")
                return transactions
            } catch {
                print("Error decoding address transactions: \(error)")
                throw error
            }
        } catch {
            print("Error fetching address transactions: \(error)")
            throw error
        }
    }
    
    /// Get the balance of a Bitcoin address (in satoshis)
    /// - Parameter address: The Bitcoin address to query
    /// - Returns: Balance information including confirmed and unconfirmed balances
    func fetchAddressBalance(address: String) async throws -> AddressBalance {
        let endpoint = "/address/\(address)/utxo"
        
        do {
            let (data, _) = try await fetchData(from: endpoint)
            
            // We'll calculate the balance from the UTXOs
            do {
                let utxos = try JSONDecoder().decode([AddressUtxo].self, from: data)
                
                var confirmed = 0
                var unconfirmed = 0
                
                for utxo in utxos {
                    if utxo.status.confirmed {
                        confirmed += utxo.value
                    } else {
                        unconfirmed += utxo.value
                    }
                }
                
                return AddressBalance(confirmed: confirmed, unconfirmed: unconfirmed)
            } catch {
                print("Error processing address balance: \(error)")
                throw error
            }
        } catch {
            print("Error fetching address balance: \(error)")
            throw error
        }
    }
    
    /// Fetch detailed transaction information including inputs and outputs
    /// - Parameter id: The transaction ID
    /// - Returns: Transaction with additional details
    func fetchDetailedTransaction(id: String) async throws -> Transaction {
        let endpoint = "/tx/\(id)"
        
        do {
            let (data, _) = try await fetchData(from: endpoint)
            print("Received \(data.count) bytes for transaction \(id)")
            
            // Try to print the first part of the response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Transaction response sample: \(jsonString.prefix(200))")
            }
            
            let decoder = JSONDecoder()
            let transaction = try decoder.decode(Transaction.self, from: data)
            print("Successfully decoded transaction: \(transaction.id)")
            return transaction
        } catch {
            print("Error decoding transaction: \(error)")
            // Print detailed decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("Type mismatch: \(type), path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: \(type), path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    
    func debugAPIResponse(endpoint: String) async {
        do {
            let (data, _) = try await fetchData(from: endpoint)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response for \(endpoint):")
                print(jsonString.prefix(1000)) // Print first 1000 chars
                
                // Try to parse as JSON to see the structure
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    print("JSON structure type: \(type(of: json))")
                    
                    if let dict = json as? [String: Any] {
                        print("Root keys: \(dict.keys)")
                    } else if let array = json as? [Any] {
                        print("Array with \(array.count) items")
                        if let firstItem = array.first as? [String: Any] {
                            print("First item keys: \(firstItem.keys)")
                        }
                    }
                }
            }
        } catch {
            print("Error fetching \(endpoint): \(error)")
        }
    }
}
