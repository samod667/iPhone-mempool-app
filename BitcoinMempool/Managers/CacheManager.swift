//
//  CacheManager.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation

/// Manages local caching of network data to reduce API calls
class CacheManager {
    static let shared = CacheManager()
    private init() {}
    
    private let fileManager = FileManager.default
    private var cacheURL: URL? {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    /// Cache duration in minutes from user settings
    var cacheDuration: Int {
        return UserDefaults.standard.integer(forKey: "cacheDuration")
    }
    
    /// Clears all cached data
    func clearCache() {
        guard let cacheURL = cacheURL else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for url in contents {
                try fileManager.removeItem(at: url)
            }
            print("Cache cleared successfully")
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
    
    /// Saves data to cache with a unique key
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: Unique identifier for the cached data
    func saveToCache(data: Data, for key: String) {
        guard let cacheURL = cacheURL else { return }
        
        let fileURL = cacheURL.appendingPathComponent(key)
        
        do {
            try data.write(to: fileURL)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cache_time_\(key)")
        } catch {
            print("Error saving to cache: \(error)")
        }
    }
    
    /// Loads cached data if available and not expired
    /// - Parameter key: Unique identifier for the cached data
    /// - Returns: Cached data if valid, nil otherwise
    func loadFromCache(for key: String) -> Data? {
        guard let cacheURL = cacheURL else { return nil }
        
        let fileURL = cacheURL.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        if let timestamp = UserDefaults.standard.object(forKey: "cache_time_\(key)") as? TimeInterval {
            let cacheDate = Date(timeIntervalSince1970: timestamp)
            let cacheExpirationInterval = TimeInterval(cacheDuration * 60)
            
            if Date().timeIntervalSince(cacheDate) > cacheExpirationInterval {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("Error loading from cache: \(error)")
            return nil
        }
    }
    
    /// Checks if a cached item exists and is valid
    /// - Parameter key: Unique identifier for the cached data
    /// - Returns: Boolean indicating if cache is valid
    func isCacheValid(for key: String) -> Bool {
        guard let cacheURL = cacheURL else { return false }
        
        let fileURL = cacheURL.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return false
        }
        
        if let timestamp = UserDefaults.standard.object(forKey: "cache_time_\(key)") as? TimeInterval {
            let cacheDate = Date(timeIntervalSince1970: timestamp)
            let cacheExpirationInterval = TimeInterval(cacheDuration * 60)
            return Date().timeIntervalSince(cacheDate) <= cacheExpirationInterval
        }
        
        return false
    }
}
