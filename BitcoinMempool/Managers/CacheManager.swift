//
//  CacheManager.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//

import Foundation

class CacheManager {
    static let shared = CacheManager()
    
    private let fileManager = FileManager.default
    private var cacheURL: URL? {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    // Default cache duration in minutes
    var cacheDuration: Int {
        get {
            return UserDefaults.standard.integer(forKey: "cacheDuration")
        }
    }
    
    // Clear all cached data
    func clearCache() {
        guard let cacheURL = cacheURL else { return }
        
        do {
            // Get all items in the cache directory
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            
            // Remove each item
            for url in contents {
                try fileManager.removeItem(at: url)
            }
            
            print("Cache cleared successfully")
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
    
    // Save data to cache
    func saveToCache(data: Data, for key: String) {
        guard let cacheURL = cacheURL else { return }
        
        let fileURL = cacheURL.appendingPathComponent(key)
        
        do {
            try data.write(to: fileURL)
            
            // Save the timestamp of when this was cached
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cache_time_\(key)")
            
            print("Saved data to cache: \(key)")
        } catch {
            print("Error saving to cache: \(error)")
        }
    }
    
    // Load data from cache
    func loadFromCache(for key: String) -> Data? {
        guard let cacheURL = cacheURL else { return nil }
        
        let fileURL = cacheURL.appendingPathComponent(key)
        
        // Check if the cache exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Check if the cache is still valid based on cacheDuration
        if let timestamp = UserDefaults.standard.object(forKey: "cache_time_\(key)") as? TimeInterval {
            let cacheDate = Date(timeIntervalSince1970: timestamp)
            
            // Convert cacheDuration from minutes to seconds
            let cacheExpirationInterval = TimeInterval(cacheDuration * 60)
            
            // Check if cache is expired
            if Date().timeIntervalSince(cacheDate) > cacheExpirationInterval {
                // Cache is expired, delete it
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }
        
        // Return the cached data
        do {
            let data = try Data(contentsOf: fileURL)
            print("Loaded data from cache: \(key)")
            return data
        } catch {
            print("Error loading from cache: \(error)")
            return nil
        }
    }
    
    // Check if a cached item exists and is valid
    func isCacheValid(for key: String) -> Bool {
        guard let cacheURL = cacheURL else { return false }
        
        let fileURL = cacheURL.appendingPathComponent(key)
        
        // Check if the cache exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return false
        }
        
        // Check if the cache is still valid based on cacheDuration
        if let timestamp = UserDefaults.standard.object(forKey: "cache_time_\(key)") as? TimeInterval {
            let cacheDate = Date(timeIntervalSince1970: timestamp)
            
            // Convert cacheDuration from minutes to seconds
            let cacheExpirationInterval = TimeInterval(cacheDuration * 60)
            
            // Check if cache is expired
            return Date().timeIntervalSince(cacheDate) <= cacheExpirationInterval
        }
        
        return false
    }
}
