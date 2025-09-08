//
//  SimpleCacheRefresh.swift
//  Clique
//
//  Created by Assistant on 2025-08-15.
//

import Foundation

extension CacheControl {
    
    /// Simple method to invalidate cache for current endpoint before refreshing
    /// Call this in .refreshable blocks before fetching new data
    func invalidateForRefresh(endpoint: String) async {
        // Extract base path from endpoint
        let pattern = endpoint
            .replacingOccurrences(of: "?.*", with: "", options: .regularExpression)
        
        await cacheManager.invalidate(patterns: [pattern])
    }
    
    /// Invalidate cache with specific patterns
    func invalidate(patterns: [String]) async {
        await cacheManager.invalidate(patterns: patterns)
    }
}

// Convenience methods for common refresh scenarios
extension CacheControl {
    
    func refreshHomeFeed() async {
        await invalidate(patterns: ["/feed/user"])
    }
    
    func refreshFlicksFeed() async {
        await invalidate(patterns: ["/feed/infinite"])
    }
    
    func refreshUserProfile(_ userId: String) async {
        await invalidate(patterns: [
            "/user/\(userId)",
            "/collection.*user/\(userId)",
            "/clique.*user/\(userId)"
        ])
    }
    
    func refreshCliqueProfile(_ cliqueId: String) async {
        await invalidate(patterns: [
            "/clique/\(cliqueId)",
            "/collection.*clique/\(cliqueId)",
            "/feed/clique/\(cliqueId)"
        ])
    }
    
    func refreshCollection(_ collectionId: String) async {
        await invalidate(patterns: [
            "/collection/\(collectionId)",
            "/comment.*\(collectionId)"
        ])
    }
    
    func refreshNotifications() async {
        await invalidate(patterns: [
            "/notification",
            "/user/followRequests",
            "/clique/invites"
        ])
    }
}