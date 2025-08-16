//
//  CacheManager.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import Foundation
import HTTPTypes

/// Core cache orchestrator managing two-tier caching (memory L1 + disk L2).
/// Provides thread-safe cache operations with automatic TTL management and LRU eviction.
///
/// Key responsibilities:
/// - Coordinates memory and disk cache operations
/// - Generates deterministic cache keys from requests
/// - Enforces cache policies and TTL values
/// - Provides invalidation APIs for manual refresh
/// - Collects cache statistics for monitoring

actor CacheManager {
    static let shared = CacheManager()
    
    /// L1 cache - Fast in-memory storage with LRU eviction
    private let memoryCache = MemoryCacheStorage()
    
    /// L2 cache - Persistent disk storage for app restarts
    private let diskCache = DiskCacheStorage()
    
    /// Current cache mode affecting all operations
    private var cacheMode: CachePolicy.CacheMode = .normal
    
    private init() {
        Task {
            await startPeriodicCleanup()
        }
    }
    
    func setCacheMode(_ mode: CachePolicy.CacheMode) {
        cacheMode = mode
    }
    
    func getCacheMode() -> CachePolicy.CacheMode {
        return cacheMode
    }
    
    /// Retrieves cached data using two-tier lookup strategy.
    /// Checks L1 (memory) first, then L2 (disk), promoting disk hits to memory.
    /// - Parameter key: The cache key to lookup
    /// - Returns: Cached data if found and not expired, nil otherwise
    func get(key: String) async -> Data? {
        switch cacheMode {
        case .bypass, .forceRefresh:
            return nil
        case .normal, .staleWhileRevalidate:
            // Try memory cache first (L1)
            if let memoryEntry = await memoryCache.get(key: key) {
                return memoryEntry.value
            }
            
            // Try disk cache (L2)
            if let diskEntry = await diskCache.get(key: key) {
                let ttl = diskEntry.expiresAt.timeIntervalSince(Date())
                if ttl > 0 {
                    // Promote to memory cache for faster future access
                    let newEntry = CacheEntry(value: diskEntry.value, ttl: ttl, etag: diskEntry.etag)
                    await memoryCache.set(key: key, value: newEntry)
                }
                return diskEntry.value
            }
            
            return nil
        }
    }
    
    /// Stores data in both cache tiers with TTL and optional ETag.
    /// - Parameters:
    ///   - key: Cache key for retrieval
    ///   - value: Data to cache
    ///   - ttl: Time-to-live in seconds
    ///   - etag: Optional ETag for conditional requests
    func set(key: String, value: Data, ttl: TimeInterval, etag: String? = nil) async {
        guard cacheMode != .bypass else { return }
        
        let entry = CacheEntry(value: value, ttl: ttl, etag: etag)
        
        // Store in both tiers for redundancy
        await memoryCache.set(key: key, value: entry)
        await diskCache.set(key: key, value: entry)
    }
    
    /// Invalidates cache entries matching the provided patterns.
    /// Supports regex patterns for flexible matching (e.g., "/user/*", "/collection.*123").
    /// Used for manual refresh scenarios to clear stale data.
    /// - Parameter patterns: Array of patterns to match against cache keys
    func invalidate(patterns: [String]) async {
        let memoryKeys = await memoryCache.keys()
        let diskKeys = await diskCache.keys()
        let allKeys = memoryKeys.union(diskKeys)
        
        for pattern in patterns {
            let keysToRemove = allKeys.filter { key in
                key.contains(pattern) || matchesPattern(key: key, pattern: pattern)
            }
            
            // Remove matching entries from both tiers
            for key in keysToRemove {
                await memoryCache.remove(key: key)
                await diskCache.remove(key: key)
            }
        }
    }
    
    func invalidateEndpoint(path: String, queryParams: [String: String]? = nil) async {
        var pattern = path
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryString = queryParams
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ".*")
            pattern += ".*" + queryString
        }
        
        await invalidate(patterns: [pattern])
    }
    
    func invalidateByKey(_ key: String) async {
        await memoryCache.remove(key: key)
        await diskCache.remove(key: key)
    }
    
    func invalidateAll() async {
        await memoryCache.removeAll()
        await diskCache.removeAll()
    }
    
    func cleanupExpired() async {
        await memoryCache.removeExpired()
        await diskCache.removeExpired()
    }
    
    private func matchesPattern(key: String, pattern: String) -> Bool {
        let regexPattern = pattern.replacingOccurrences(of: ".*", with: ".*")
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else { return false }
        let range = NSRange(location: 0, length: key.utf16.count)
        return regex.firstMatch(in: key, options: [], range: range) != nil
    }
    
    private func startPeriodicCleanup() async {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.cleanupExpired()
            }
        }
    }
    
    func cacheStats() async -> CacheStats {
        let memoryInfo = await memoryCache.cacheInfo()
        let diskInfo = await diskCache.cacheInfo()
        
        return CacheStats(
            memoryEntries: memoryInfo.entries,
            memorySize: memoryInfo.size,
            diskEntries: diskInfo.entries,
            diskSize: diskInfo.size
        )
    }
    
    /// Generates a deterministic cache key from HTTP request components.
    /// Ensures identical requests always produce the same key for cache lookup.
    /// - Parameters:
    ///   - request: The HTTP request to generate key from
    ///   - body: Optional request body for POST/PUT operations
    /// - Returns: A unique, deterministic cache key string
    func createCacheKey(from request: HTTPRequest, body: Data?) -> String {
        var components: [String] = []
        
        components.append(request.method.rawValue)
        components.append(request.path ?? "")
        
        // Sort query parameters for consistency
        if let queryItems = URLComponents(string: request.path ?? "")?.queryItems {
            let sortedQuery = queryItems.sorted { $0.name < $1.name }
                .map { "\($0.name)=\($0.value ?? "")" }
                .joined(separator: "&")
            components.append(sortedQuery)
        }
        
        // Add body hash for non-GET requests
        if let body = body, request.method != .get {
            let bodyHash = body.hashValue
            components.append(String(bodyHash))
        }
        
        return components.joined(separator: ":")
    }
}

struct CacheStats {
    let memoryEntries: Int
    let memorySize: Int
    let diskEntries: Int
    let diskSize: Int
    
    var formattedMemorySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(memorySize), countStyle: .memory)
    }
    
    var formattedDiskSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskSize), countStyle: .file)
    }
}