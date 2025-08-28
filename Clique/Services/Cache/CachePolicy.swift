//
//  CachePolicy.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import Foundation
import HTTPTypes

/// Defines caching policies including TTL values, cache modes, and invalidation rules.
/// Central configuration for cache behavior across different endpoint types.
struct CachePolicy {
    
    /// Cache operation modes affecting read/write behavior
    enum CacheMode {
        case normal                 // Standard caching with TTL
        case bypass                 // Skip cache entirely
        case forceRefresh          // Clear cache then fetch
        case staleWhileRevalidate  // Return stale while fetching fresh
    }
    
    /// Default TTL for endpoints without specific configuration
    private static let defaultTTL: TimeInterval = 300  // 5 minutes
    
    /// Determines Time-To-Live for cache entries based on endpoint type.
    /// Different content types have different freshness requirements.
    /// - Parameters:
    ///   - path: The API endpoint path
    ///   - method: HTTP method (only GET is cached)
    /// - Returns: TTL in seconds, or nil if not cacheable
    static func getTTL(for path: String, method: HTTPRequest.Method) -> TimeInterval? {
        guard method == .get else { return nil }
        
        // User data - relatively stable (10 min)
        if path.contains("/user/self") {
            return 600
        }
        if path.contains("/user/") {
            return 600
        }
        
        // Clique data - moderate updates (5 min)
        if path.contains("/clique/") && path.contains("/members") {
            return 300
        }
        if path.contains("/clique/") {
            return 300
        }
        
        // Collection data - moderate updates (5 min)
        if path.contains("/collection/") && !path.contains("/feed") {
            return 300
        }
        
        // Feed data - frequent updates (2 min)
        if path.contains("/feed") || path.contains("/infinite") {
            return 120
        }
        
        // Search results - very dynamic (1 min)
        if path.contains("/search") {
            return 60
        }
        
        // Comments - semi-stable (3 min)
        if path.contains("/comments") {
            return 180
        }
        
        // Notifications - important freshness (30 sec)
        if path.contains("/notifications") {
            return 30
        }
        
        // Follow status - stable (5 min)
        if path.contains("/follow") && path.contains("/status") {
            return 300
        }
        
        return defaultTTL
    }
    
    /// Determines if a request should be cached based on method and path.
    /// Excludes sensitive endpoints like auth and real-time data.
    /// - Parameters:
    ///   - method: HTTP method (only GET is cached)
    ///   - path: The API endpoint path
    /// - Returns: true if request should be cached
    static func shouldCache(method: HTTPRequest.Method, path: String) -> Bool {
        guard method == .get else { return false }
        
        // Never cache authentication endpoints
        if path.contains("/auth") || path.contains("/token") {
            return false
        }
        
        // Never cache device/push notification endpoints
        if path.contains("/device") || path.contains("/push") {
            return false
        }
        
        return true
    }
    
    /// Returns cache invalidation patterns for mutation operations.
    /// When data is created/updated/deleted, related cached data must be cleared.
    /// - Parameters:
    ///   - path: The API endpoint path being mutated
    ///   - method: HTTP method (POST/PUT/DELETE)
    /// - Returns: Array of patterns to invalidate
    static func getInvalidationPatterns(for path: String, method: HTTPRequest.Method) -> [String] {
        var patterns: [String] = []
        
        switch method {
        case .post:
            if path.contains("/collection") && !path.contains("/item") {
                patterns.append("/collection")
                patterns.append("/feed")
            }
            if path.contains("/collection") && path.contains("/item") {
                let collectionId = extractCollectionId(from: path)
                if let id = collectionId {
                    patterns.append("/collection/\(id)")
                }
            }
            if path.contains("/comment/create") {
                // Invalidate comment lists when a new comment is created
                patterns.append("/comment/collectionItem")
                patterns.append("/comment/replies")
            }
            if path.contains("/clique/create") {
                // Invalidate clique lists when a new clique is created
                patterns.append("/clique/user")
                patterns.append("/clique/getMembers")
                patterns.append("/feed")  // Feed might show new cliques
            }
            if path.contains("/user/follow") || path.contains("/user/unfollow") {
                // Invalidate user data and follow status when following/unfollowing
                // Note: The user ID is in the request body, not the path
                // We invalidate broadly since we can't extract the ID from body here
                patterns.append("/user/")
                patterns.append("/follow")
            }
            if path.contains("/clique") && path.contains("/invite") {
                let cliqueId = extractCliqueId(from: path)
                if let id = cliqueId {
                    patterns.append("/clique/\(id)")
                }
            }
            if path.contains("/comment/like") || path.contains("/comment/unlike") {
                // Invalidate comment cache when likes change
                patterns.append("/comment/collectionItem")
                patterns.append("/comment/replies")
            }
            
        case .put:
            if path.contains("/user") {
                let userId = extractUserId(from: path)
                if let id = userId {
                    patterns.append("/user/\(id)")
                    patterns.append("/user/self")
                }
            }
            if path.contains("/clique") {
                let cliqueId = extractCliqueId(from: path)
                if let id = cliqueId {
                    patterns.append("/clique/\(id)")
                    patterns.append("/feed.*clique.*\(id)")
                }
            }
            if path.contains("/collection") {
                let collectionId = extractCollectionId(from: path)
                if let id = collectionId {
                    patterns.append("/collection/\(id)")
                    patterns.append("/feed")
                }
            }
            
        case .delete:
            if path.contains("/collection") && path.contains("/item") {
                let collectionId = extractCollectionId(from: path)
                if let id = collectionId {
                    patterns.append("/collection/\(id)")
                }
            }
            if path.contains("/collection") && !path.contains("/item") {
                patterns.append("/collection")
                patterns.append("/feed")
            }
            if path.contains("/comment/delete") {
                // Invalidate comment lists when a comment is deleted
                patterns.append("/comment/collectionItem")
                patterns.append("/comment/replies")
            }
            if path.contains("/user/follow") || path.contains("/user/unfollow") {
                // Invalidate user data and follow status when following/unfollowing
                // Note: The user ID is in the request body, not the path
                // We invalidate broadly since we can't extract the ID from body here
                patterns.append("/user/")
                patterns.append("/follow")
            }
            
        default:
            break
        }
        
        return patterns
    }
    
    private static func extractUserId(from path: String) -> String? {
        let pattern = "/user/([a-f0-9-]{36})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: path.utf16.count)
        guard let match = regex.firstMatch(in: path, options: [], range: range) else { return nil }
        guard let matchRange = Range(match.range(at: 1), in: path) else { return nil }
        return String(path[matchRange])
    }
    
    private static func extractCliqueId(from path: String) -> String? {
        let pattern = "/clique/([a-f0-9-]{36})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: path.utf16.count)
        guard let match = regex.firstMatch(in: path, options: [], range: range) else { return nil }
        guard let matchRange = Range(match.range(at: 1), in: path) else { return nil }
        return String(path[matchRange])
    }
    
    private static func extractCollectionId(from path: String) -> String? {
        let pattern = "/collection/([a-f0-9-]{36})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: path.utf16.count)
        guard let match = regex.firstMatch(in: path, options: [], range: range) else { return nil }
        guard let matchRange = Range(match.range(at: 1), in: path) else { return nil }
        return String(path[matchRange])
    }
    
    private static func extractCollectionItemId(from path: String) -> String? {
        let pattern = "/item/([a-f0-9-]{36})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: path.utf16.count)
        guard let match = regex.firstMatch(in: path, options: [], range: range) else { return nil }
        guard let matchRange = Range(match.range(at: 1), in: path) else { return nil }
        return String(path[matchRange])
    }
}