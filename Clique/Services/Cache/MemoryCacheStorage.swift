//
//  MemoryCacheStorage.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import Foundation

actor MemoryCacheStorage: CacheStorage {
    typealias Value = Data
    
    private var cache: [String: CacheEntry<Data>] = [:]
    private let maxSize: Int
    private let maxEntries: Int
    private var accessOrder: [String] = []
    private var currentSize: Int = 0
    
    init(maxSize: Int = 50 * 1024 * 1024, maxEntries: Int = 1000) {
        self.maxSize = maxSize
        self.maxEntries = maxEntries
    }
    
    func get(key: String) async -> CacheEntry<Data>? {
        guard let entry = cache[key] else { return nil }
        
        if entry.isExpired {
            await remove(key: key)
            return nil
        }
        
        updateAccessOrder(key: key)
        return entry
    }
    
    func set(key: String, value: CacheEntry<Data>) async {
        let dataSize = value.value.count
        
        if let existingEntry = cache[key] {
            currentSize -= existingEntry.value.count
        }
        
        while (currentSize + dataSize > maxSize || cache.count >= maxEntries) && !cache.isEmpty {
            await evictLRU()
        }
        
        cache[key] = value
        currentSize += dataSize
        updateAccessOrder(key: key)
    }
    
    func remove(key: String) async {
        if let entry = cache.removeValue(forKey: key) {
            currentSize -= entry.value.count
            accessOrder.removeAll { $0 == key }
        }
    }
    
    func removeAll() async {
        cache.removeAll()
        accessOrder.removeAll()
        currentSize = 0
    }
    
    func removeExpired() async {
        let expiredKeys = cache.compactMap { key, entry in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            await remove(key: key)
        }
    }
    
    func keys() async -> Set<String> {
        Set(cache.keys)
    }
    
    private func updateAccessOrder(key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private func evictLRU() async {
        guard let lruKey = accessOrder.first else { return }
        await remove(key: lruKey)
    }
    
    func cacheInfo() async -> (entries: Int, size: Int) {
        return (cache.count, currentSize)
    }
}