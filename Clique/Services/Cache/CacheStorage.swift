//
//  CacheStorage.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import Foundation

protocol CacheStorage: Actor {
    associatedtype Value: Codable
    
    func get(key: String) async -> CacheEntry<Value>?
    func set(key: String, value: CacheEntry<Value>) async
    func remove(key: String) async
    func removeAll() async
    func removeExpired() async
    func keys() async -> Set<String>
}

struct CacheEntry<T: Codable>: Codable {
    let value: T
    let expiresAt: Date
    let etag: String?
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    init(value: T, ttl: TimeInterval, etag: String? = nil) {
        self.value = value
        self.expiresAt = Date().addingTimeInterval(ttl)
        self.etag = etag
    }
}