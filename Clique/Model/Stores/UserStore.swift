//
//  UserStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/21/25.
//

import Foundation

/// Extracts timestamp from S3 URL query parameters for expiration checking.
///
/// This utility function parses AWS S3 URLs to extract the X-Amz-Date parameter,
/// which is used to determine when signed URLs will expire.
///
/// - Parameter urlString: The S3 URL to parse
/// - Returns: Date when the URL was signed, or nil if parsing fails
///
/// ## Usage
/// ```swift
/// let timestamp = extractTimestamp(from: user.profilePic)
/// let isExpired = timestamp?.timeIntervalSinceNow ?? 0 < -3600 // 1 hour
/// ```
func extractTimestamp(from urlString: String) -> Date? {
    guard let url = URLComponents(string: urlString),
          let queryItems = url.queryItems else { return nil }

    if let timestampString = queryItems.first(where: { $0.name == "X-Amz-Date" })?.value {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: timestampString)
    }
    
    return nil
}

/// Observable store managing user data throughout the app lifecycle.
///
/// This store provides centralized user data management with intelligent caching,
/// partial updates, and S3 URL expiration handling. It maintains a dictionary of
/// all loaded users and tracks the currently authenticated user.
///
/// ## Key Features
/// - **Smart caching**: Keeps user data in memory for fast access
/// - **Partial updates**: Only updates changed properties to prevent unnecessary UI refreshes
/// - **URL management**: Automatically handles S3 URL expiration for profile pictures
/// - **Relationship tracking**: Manages follow/block relationships between users
/// - **Thread safety**: All operations are @MainActor for UI consistency
///
/// ## Usage
/// ```swift
/// @Environment(UserStore.self) private var userStore
/// 
/// // Access current user
/// if let currentUser = userStore.currentUser {
///     Text("Hello, \(currentUser.firstname)")
/// }
/// 
/// // Update user data
/// await userStore.updateUser(updatedUser)
/// ```
///
/// ## Architecture Integration
/// - Injected as environment object throughout the app
/// - Updated by ``UserService`` after API calls
/// - Observed by UI components for automatic updates
/// - Reset during logout for security
///
/// - Important: Always access from @MainActor context
/// - Note: Designed to work seamlessly with SwiftUI's observation system
@Observable @MainActor final class UserStore {
    /// Dictionary mapping user IDs to User objects for fast lookup
    var users = [String: User]()
    
    /// ID of the currently authenticated user
    var currentUserId: String?
    
    /// Computed property providing easy access to current user data
    var currentUser: User? {
        guard let currentUserId else { return nil }
        
        return users[currentUserId]
    }
    
    /// Updates or adds a user with intelligent partial updating.
    ///
    /// This method performs smart updates by only changing properties that have
    /// actually been modified. This prevents unnecessary UI refreshes and maintains
    /// optimal performance in lists and other UI components.
    ///
    /// - Parameters:
    ///   - user: The user data to update or add
    ///   - forceUpdateURL: Whether to force update profile picture URL regardless of expiration
    ///
    /// ## Update Strategy
    /// - **New users**: Added directly to the store
    /// - **Existing users**: Only modified properties are updated
    /// - **Profile pictures**: Smart URL expiration checking (unless forced)
    /// - **Relationships**: Always updated when provided
    ///
    /// ## Usage
    /// ```swift
    /// // Standard update (checks URL expiration)
    /// userStore.updateUser(updatedUser)
    /// 
    /// // Force URL refresh (bypass expiration check)
    /// userStore.updateUser(updatedUser, forceUpdateURL: true)
    /// ```
    ///
    /// - Note: This method is optimized for SwiftUI observation efficiency
    func updateUser(_ user: User, forceUpdateURL: Bool = false) {
        guard var existingUser = users[user.id] else {
            users[user.id] = user // If the user doesn't exist, add it
            return
        }
        
        // Update only the changed fields
        if existingUser.firstname != user.firstname {
            existingUser.firstname = user.firstname
        }
        if existingUser.lastname != user.lastname {
            existingUser.lastname = user.lastname
        }
        if existingUser.username != user.username {
            existingUser.username = user.username
        }
        // Smart URL updating with expiration checking
        if forceUpdateURL || shouldUpdatePhotoUrls(existingUser.profilePic, user.profilePic) {
            existingUser.profilePic = user.profilePic
        }
        if existingUser.bio != user.bio {
            existingUser.bio = user.bio
        }
        if existingUser.isPrivate != user.isPrivate {
            existingUser.isPrivate = user.isPrivate
        }
        
        if existingUser.numCliques != user.numCliques {
            existingUser.numCliques = user.numCliques
        }
        if existingUser.numFollowers != user.numFollowers {
            existingUser.numFollowers = user.numFollowers
        }
        if existingUser.numFollowing != user.numFollowing {
            existingUser.numFollowing = user.numFollowing
        }
        
        if let newCliques = user.cliques, newCliques != existingUser.cliques {
            existingUser.cliques = newCliques
        }
        if let newPinnedCliques = user.pinnedCliques, newPinnedCliques != existingUser.pinnedCliques {
            existingUser.pinnedCliques = newPinnedCliques
        }
        if let newSettings = user.settings, newSettings != existingUser.settings {
            existingUser.settings = newSettings
        }
        if let newBlockedCliques = user.blockedCliques, newBlockedCliques != existingUser.blockedCliques {
            existingUser.blockedCliques = newBlockedCliques
        }
        if let newBlockedUsers = user.blockedUsers, newBlockedUsers != existingUser.blockedUsers {
            existingUser.blockedUsers = newBlockedUsers
        }
        
        // Always update relationship data when provided
        if user.relationship != nil {
            existingUser.relationship = user.relationship
        }
        
        users[user.id] = existingUser
    }
    
    /// Batch updates multiple users efficiently.
    ///
    /// This convenience method applies ``updateUser(_:forceUpdateURL:)`` to an array
    /// of users, maintaining the same intelligent update behavior for each.
    ///
    /// - Parameter users: Array of users to update
    ///
    /// ## Usage
    /// ```swift
    /// // Update multiple users from API response
    /// let searchResults = try await UserService.searchUsers(input)
    /// userStore.updateUsers(searchResults)
    /// ```
    ///
    /// - Note: Each user is updated individually with partial update logic
    func updateUsers(_ users: [User]) {
        users.forEach({ updateUser($0) })
    }
    
    /// Clears all user data from the store.
    ///
    /// This method completely resets the store to its initial state,
    /// removing all cached user data and clearing the current user.
    /// Typically called during logout or account switching.
    ///
    /// ## When to Use
    /// - User logout
    /// - Account switching
    /// - App reset scenarios
    /// - Testing/debugging
    ///
    /// ## Usage
    /// ```swift
    /// // During logout process
    /// userStore.reset()
    /// // Store is now empty and ready for new user
    /// ```
    ///
    /// - Warning: This operation cannot be undone and will clear all cached user data
    func reset() {
        users = [String: User]()
        currentUserId = nil
    }
}
