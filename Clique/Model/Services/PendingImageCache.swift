//
//  PendingImageCache.swift
//  Clique
//
//  Created by Assistant on pending image cache implementation.
//

import Foundation
import SwiftUI

/// Information about a cached device asset for a pending collection item
struct CachedAssetInfo: Codable, Hashable {
    /// PHAsset.localIdentifier from device Photos library
    let assetIdentifier: String
    /// When this mapping was created
    let timestamp: Date
    /// The media type (PHOTO, VIDEO, or LIVE)
    let mediaType: MediaType

    /// Check if this cache entry has expired (older than TTL)
    func isExpired(ttl: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

/// Manages mapping between collection item IDs and device Photos library assets
///
/// This service enables showing users their device photos immediately during upload,
/// even while the backend is processing quality variants. The mapping persists across
/// app sessions with a 24-hour TTL to handle the edge case where users quit the app
/// during backend processing.
///
/// ## Usage
/// ```swift
/// // Store mapping after getting collection item ID from backend
/// PendingImageCache.shared.store(
///     collectionItemId: "item-123",
///     assetIdentifier: "asset-abc",
///     mediaType: .PHOTO
/// )
///
/// // Retrieve mapping when displaying PENDING items
/// if let info = PendingImageCache.shared.get("item-123") {
///     // Load from device Photos library
/// }
/// ```
///
/// ## Architecture
/// - **Persistence**: Uses AppStorage for cross-session persistence
/// - **Performance**: In-memory cache for fast lookups during app session
/// - **TTL**: 24-hour expiration handles most edge cases
/// - **Thread Safety**: All operations run on MainActor
///
/// - Important: Call `cleanup()` on app launch to remove expired entries
@MainActor
final class PendingImageCache: ObservableObject {
    /// Shared singleton instance
    static let shared = PendingImageCache()

    /// Time-to-live for cache entries (24 hours)
    private let ttl: TimeInterval = 24 * 60 * 60

    /// In-memory cache for fast lookups during app session
    private var memoryCache: [String: CachedAssetInfo] = [:]

    /// Persistent storage key for AppStorage
    private let storageKey = "pendingImageCache"

    /// AppStorage wrapper for persistent cache
    /// Stores dictionary as JSON data
    @AppStorage("pendingImageCache") private var persistentCacheData: Data = Data()

    private init() {
        // Load persistent cache into memory on initialization
        loadFromPersistentStorage()
    }

    /// Store a mapping between collection item ID and device asset
    ///
    /// - Parameters:
    ///   - collectionItemId: The backend collection item ID
    ///   - assetIdentifier: The PHAsset.localIdentifier from device
    ///   - mediaType: The type of media (PHOTO, VIDEO, LIVE)
    func store(collectionItemId: String, assetIdentifier: String, mediaType: MediaType) {
        let info = CachedAssetInfo(
            assetIdentifier: assetIdentifier,
            timestamp: Date(),
            mediaType: mediaType
        )

        // Update memory cache
        memoryCache[collectionItemId] = info

        // Persist to storage
        saveToPersistentStorage()

        print("📦 [PENDING-CACHE] Stored: itemId=\(collectionItemId), assetId=\(assetIdentifier), type=\(mediaType.rawValue)")
    }

    /// Retrieve cached asset info for a collection item
    ///
    /// - Parameter collectionItemId: The collection item ID to look up
    /// - Returns: CachedAssetInfo if found and not expired, nil otherwise
    func get(_ collectionItemId: String) -> CachedAssetInfo? {
        guard let info = memoryCache[collectionItemId] else {
            return nil
        }

        // Check if expired
        if info.isExpired(ttl: ttl) {
            print("⏰ [PENDING-CACHE] Expired: itemId=\(collectionItemId)")
            remove(collectionItemId)
            return nil
        }

        print("✅ [PENDING-CACHE] Hit: itemId=\(collectionItemId), assetId=\(info.assetIdentifier)")
        return info
    }

    /// Remove a specific cache entry
    ///
    /// - Parameter collectionItemId: The collection item ID to remove
    func remove(_ collectionItemId: String) {
        memoryCache.removeValue(forKey: collectionItemId)
        saveToPersistentStorage()
        print("🗑️ [PENDING-CACHE] Removed: itemId=\(collectionItemId)")
    }

    /// Remove all cache entries
    func clear() {
        memoryCache.removeAll()
        saveToPersistentStorage()
        print("🗑️ [PENDING-CACHE] Cleared all entries")
    }

    /// Clean up expired cache entries
    ///
    /// Should be called on app launch to remove stale mappings.
    /// Removes entries older than the TTL period.
    func cleanup() {
        let beforeCount = memoryCache.count

        // Filter out expired entries
        memoryCache = memoryCache.filter { _, info in
            !info.isExpired(ttl: ttl)
        }

        let removedCount = beforeCount - memoryCache.count

        if removedCount > 0 {
            saveToPersistentStorage()
            print("🧹 [PENDING-CACHE] Cleanup: removed \(removedCount) expired entries")
        }
    }

    // MARK: - Private Persistence Methods

    /// Load cache from persistent storage into memory
    private func loadFromPersistentStorage() {
        guard !persistentCacheData.isEmpty else {
            print("📦 [PENDING-CACHE] No persistent data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            memoryCache = try decoder.decode([String: CachedAssetInfo].self, from: persistentCacheData)
            print("📦 [PENDING-CACHE] Loaded \(memoryCache.count) entries from storage")
        } catch {
            print("❌ [PENDING-CACHE] Failed to load from storage: \(error)")
            memoryCache = [:]
        }
    }

    /// Save current memory cache to persistent storage
    private func saveToPersistentStorage() {
        do {
            let encoder = JSONEncoder()
            persistentCacheData = try encoder.encode(memoryCache)
        } catch {
            print("❌ [PENDING-CACHE] Failed to save to storage: \(error)")
        }
    }
}

// MARK: - MediaType Extension

extension MediaType {
    /// Convert from Components.Schemas.MediaType to this enum if needed
    init?(from schemaType: Components.Schemas.MediaType?) {
        guard let schemaType = schemaType else { return nil }
        switch schemaType {
        case .PHOTO: self = .PHOTO
        case .VIDEO: self = .VIDEO
        case .LIVE: self = .LIVE
        }
    }
}
