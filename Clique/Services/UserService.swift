//
//  CliqueService.swift
//  Clique
//
//  Created by Rod Tavangar on 6/13/24.
//

import SwiftUI
import FirebaseAuth
import OpenAPIRuntime
import OpenAPIURLSession

/// Service class for all user-related API operations.
///
/// This service provides a clean interface for user data operations including
/// fetching user profiles, search functionality, and managing user relationships.
/// All methods are static and thread-safe, designed to be called from any context.
///
/// ## Architecture
/// - **Type-safe APIs**: Uses OpenAPI-generated types for all requests/responses
/// - **Error handling**: Consistent error mapping with ``ServiceError`` enum
/// - **DTO mapping**: Automatic conversion from API DTOs to domain models
/// - **Async/await**: Modern concurrency throughout
///
/// ## Usage Examples
/// ```swift
/// // Fetch current user profile
/// try await UserService.fetchCurrentUser(userStore: userStore)
/// 
/// // Get user by ID
/// let user = try await UserService.getUserById("user123")
/// 
/// // Search users
/// let searchInput = Operations.getUserSearch.Input(
///     query: .init(query: "john", page: 0, size: 20)
/// )
/// let users = try await UserService.searchUsers(searchInput)
/// ```
///
/// - Important: All methods require valid authentication through ``ClientManager``
/// - Note: Automatically updates ``UserStore`` when fetching current user data
class UserService {
//    @Published var currentUser: User?
    
//    static let shared = UserService()
    
    //    @MainActor
    /// Fetches the current authenticated user and updates the user store.
    ///
    /// This method retrieves the current user's profile from the server and
    /// automatically updates the provided ``UserStore`` with the user data.
    /// It sets both the current user ID and the complete user profile.
    ///
    /// - Parameter userStore: The store to update with current user data
    /// - Throws: ``ServiceError/userDoesNotExist`` if user not found, or network errors
    ///
    /// ## Usage
    /// ```swift
    /// @Environment(UserStore.self) private var userStore
    /// 
    /// func loadCurrentUser() async {
    ///     do {
    ///         try await UserService.fetchCurrentUser(userStore: userStore)
    ///         // User store now contains current user data
    ///     } catch {
    ///         // Handle authentication or network errors
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Must be called with valid authentication token
    static func fetchCurrentUser(userStore: UserStore) async throws {
        print("fetching current user")
        let user = try await UserService.fetchSelf()
        
        await MainActor.run {
            userStore.currentUserId = user.id
        }
        await userStore.updateUser(user)
    }
    
    // MARK: - User Retrieval
    
    /// Fetches a user profile by their unique identifier.
    ///
    /// This method retrieves detailed user information including profile data,
    /// relationship status, and other public information.
    ///
    /// - Parameter uid: The unique identifier of the user to fetch
    /// - Returns: Complete ``User`` domain model with profile information
    /// - Throws: ``ServiceError/userDoesNotExist`` if user not found
    ///
    /// ## Usage
    /// ```swift
    /// let user = try await UserService.getUserById("user_123")
    /// print("User name: \(user.name)")
    /// ```
    ///
    /// - Note: Returns public profile information only; use ``fetchSelf()`` for private data
    static func getUserById(_ uid: String) async throws -> User {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getUser(path: .init(userId: uid)) {
        case .ok(let response):
            switch response.body {
            case .json(let user):
                return mapToUser(user)
            }
        default:
            print("fetch user by id failed")
            throw ServiceError.userDoesNotExist
        }
    }
    
    /// Fetches the authenticated user's own profile with private information.
    ///
    /// This method retrieves the complete profile of the currently authenticated
    /// user, including private information not available in public profiles.
    ///
    /// - Returns: Complete ``User`` domain model with private profile data
    /// - Throws: ``ServiceError/userDoesNotExist`` if authentication fails
    ///
    /// ## Usage
    /// ```swift
    /// let currentUser = try await UserService.fetchSelf()
    /// // Access to private profile information
    /// ```
    ///
    /// - Important: Requires valid authentication token
    /// - Note: Typically called during app initialization or after login
    static func fetchSelf() async throws -> User {
        print("fetching self")
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getUserSelf() {
        case .ok(let response):
            switch response.body {
            case .json(let user):
                print("returning")
                return mapToUser(user)
            }
        default:
            print("fetch self user does not exist")
            throw ServiceError.userDoesNotExist
        }
    }
    
    /// Finds users by their phone numbers for contact discovery.
    ///
    /// This method allows finding app users from the device's contact list
    /// by matching phone numbers. Used for friend discovery and invitations.
    ///
    /// - Parameter input: OpenAPI input containing phone numbers to search
    /// - Returns: Array of ``User`` objects found by phone number matching
    /// - Throws: ``ServiceError/somethingWentWrong`` for API errors
    ///
    /// ## Usage
    /// ```swift
    /// let input = Operations.getUserByPhoneNumbers.Input(
    ///     body: .json(["1234567890", "0987654321"])
    /// )
    /// let foundUsers = try await UserService.getUsersByNumbers(input)
    /// ```
    ///
    /// - Important: Respects user privacy settings for phone number discoverability
    /// - Note: Returns only users who have opted into phone number discovery
    static func getUsersByNumbers(_ input: Operations.getUserByPhoneNumbers.Input) async throws -> [User] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getUserByPhoneNumbers(input) {
        case .ok(let response):
            switch response.body {
            case .json(let users):
                let users = mapToUsers(users)
                for user in users {
                    print(user.number)
                }
                return users
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        case .undocumented(statusCode: let statusCode, _):
            print(statusCode)
        default:
            print("DEBUG: get users by phone numbers failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}
    
// MARK: - Search Operations

/// Extension providing user search functionality.
///
/// These methods enable searching for users across different contexts:
/// global search, follower search, and following search.
extension UserService {
    /// Searches for users globally across the entire platform.
    ///
    /// This method performs a global user search based on usernames, display names,
    /// or other searchable user attributes. Results are paginated and ranked by relevance.
    ///
    /// - Parameter input: Search parameters including query, page, and size
    /// - Returns: Array of ``User`` objects matching the search criteria
    /// - Throws: ``ServiceError/somethingWentWrong`` for API errors
    ///
    /// ## Usage
    /// ```swift
    /// let input = Operations.getUserSearch.Input(
    ///     query: .init(query: "john", page: 0, size: 20)
    /// )
    /// let users = try await UserService.searchUsers(input)
    /// ```
    ///
    /// - Note: Results respect user privacy settings and blocking relationships
    static func searchUsers(_ input: Operations.getUserSearch.Input) async throws -> [User] {
        let client = try await ClientManager.shared.createClient()

        switch try await client.getUserSearch(input) {
        case .ok(let response):
            switch response.body {
            case .json(let users):
                return mapToUsers(users)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: search users failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    /// Searches within a specific user's followers list.
    ///
    /// This method allows searching for specific users within someone's follower list,
    /// useful for finding mutual connections or specific followers.
    ///
    /// - Parameter input: Search parameters including user ID, query, page, and size
    /// - Returns: Array of ``User`` objects from the followers list matching the query
    /// - Throws: ``ServiceError/somethingWentWrong`` for API errors
    ///
    /// ## Usage
    /// ```swift
    /// let input = Operations.getUserFollowersSearch.Input(
    ///     path: .init(userId: "user123"),
    ///     query: .init(query: "jane", page: 0, size: 10)
    /// )
    /// let followers = try await UserService.searchUserFollowers(input)
    /// ```
    ///
    /// - Important: Respects privacy settings - only returns visible followers
    static func searchUserFollowers(_ input: Operations.getUserFollowersSearch.Input) async throws -> [User] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getUserFollowersSearch(input) {
        case .ok(let response):
            switch response.body {
            case .json(let users):
                return mapToUsers(users)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("search user followers failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    /// Searches within a specific user's following list.
    ///
    /// This method allows searching for specific users within someone's following list,
    /// useful for finding mutual connections or people they follow.
    ///
    /// - Parameter input: Search parameters including user ID, query, page, and size
    /// - Returns: Array of ``User`` objects from the following list matching the query
    /// - Throws: ``ServiceError/somethingWentWrong`` for API errors
    ///
    /// ## Usage
    /// ```swift
    /// let input = Operations.getUserFollowingSearch.Input(
    ///     path: .init(userId: "user123"),
    ///     query: .init(query: "alex", page: 0, size: 10)
    /// )
    /// let following = try await UserService.searchUserFollowing(input)
    /// ```
    ///
    /// - Important: Respects privacy settings - only returns visible following lists
    static func searchUserFollowing(_ input: Operations.getUserFollowingSearch.Input) async throws -> [User] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getUserFollowingSearch(input) {
        case .ok(let response):
            switch response.body {
            case .json(let users):
                return mapToUsers(users)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("search user following failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Register User
extension UserService {
    /// Returns user and join number
    ///
    /// '''
    static func registerUser(_ input: Operations.registerUser.Input) async throws -> (User, Int) {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.registerUser(input) {
        case .ok(let response):
            switch response.body {
            case .json(let userResponse):
                return (mapToUser(userResponse), Int(userResponse.joinNumber!))
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("register user failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func checkUsernameUnique(_ input: Operations.checkUsernameUnique.Input) async throws -> Bool {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.checkUsernameUnique(input) {
        case .ok(let response):
            switch response.body {
            case .json(let isUnique):
                return isUnique.isUnique!
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("check username unique failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func updateUserDeviceToken(_ input: Operations.updateUserDeviceToken.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.updateUserDeviceToken(input) {
        case .ok:
            return
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: update user device token failed")
        }
        throw ServiceError.somethingWentWrong
    }
}
    
// MARK: - Edit User
extension UserService {
    static func editUser(_ input: Operations.editUser.Input) async throws -> User {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.editUser(input) {
        case .ok(let response):
            switch response.body {
            case .json(let userResponse):
                return mapToUser(userResponse)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: edit user failed")
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Follow
extension UserService {
    /// Get follow status
    static func getFollowStatus(input: Operations.getFollowStatus.Input) async throws -> UserRelationship {
        print("getting follow status")
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getFollowStatus(input) {
        case .ok(let response):
            switch response.body {
            case .json(let status):
                return mapToUserRelationship(status)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get follow status failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    /// Follow user
    static func followUser(_ input: Operations.followUser.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.followUser(input) {
        case .created:
            return
        case .badRequest(let error):
            print(error.body)
        case .internalServerError(let error):
            print(error)
        default:
            print("follow user failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    /// Unfollow user
    static func unfollowUser(_ input: Operations.unfollowUser.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.unfollowUser(input) {
        case .noContent:
            return
        default:
            print("unfollow user failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    /// Get the follow requests for the current user
    static func getFollowRequests(_ input: Operations.getFollowRequests.Input) async throws -> [FollowRequest] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getFollowRequests(input) {
        case .ok(let response):
            switch response.body {
            case .json(let frs):
                return frs.followRequests!.map { mapToFollowRequest($0) }
            }
        default:
            print("get follow requests failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func acceptFollowRequest(_ input: Operations.acceptFollowRequest.Input) async throws {
        print("accepting")
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.acceptFollowRequest(input) {
        case .ok:
            return
        default:
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func declineFollowRequest(_ input: Operations.declineFollowRequest.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.declineFollowRequest(input) {
        case .ok:
            return
        default:
            throw ServiceError.somethingWentWrong
        }
    }
}

// MARK: - Block
extension UserService {
    static func blockUser(_ input: Operations.blockUser.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.blockUser(input) {
        case .ok:
            return
        default:
            throw ServiceError.somethingWentWrong
        }
    }
}








// TODO: deprecate

//extension UserService {
//    
//    static func fetchCollectionCellUsers(id: String) -> [User] {
//        [User.MOCK_USERS[0], User.MOCK_USERS[1], User.MOCK_USERS[2], User.MOCK_USERS[3], User.MOCK_USERS[4]]
//    }
//    
//    static func fetchUsers(forConfig config: UserListConfig) -> [User] {
//        switch config {
//        case .followers/*(let uid)*/:
//            return []
//        case .following/*(let uid)*/:
//            return []
//        case .likes/*(let postId)*/:
//            return []
//        case .search:
//            return fetchAllUsers()
//        case .members(let cliqueID):
//            switch cliqueID {
//            case "1":
//                return [User.MOCK_USERS[0], User.MOCK_USERS[1]]
//            case "2":
//                return [User.MOCK_USERS[2], User.MOCK_USERS[3]]
//            case "3":
//                return [User.MOCK_USERS[0], User.MOCK_USERS[2]]
//            case "4":
//                return [User.MOCK_USERS[2], User.MOCK_USERS[3], User.MOCK_USERS[4]]
//            case "5":
//                return [User.MOCK_USERS[0], User.MOCK_USERS[2], User.MOCK_USERS[3], User.MOCK_USERS[4]]
//            case "6":
//                return [User.MOCK_USERS[0], User.MOCK_USERS[1], User.MOCK_USERS[6], User.MOCK_USERS[7], User.MOCK_USERS[8], User.MOCK_USERS[9], User.MOCK_USERS[10], User.MOCK_USERS[11], User.MOCK_USERS[12], User.MOCK_USERS[13], User.MOCK_USERS[14], User.MOCK_USERS[15], User.MOCK_USERS[16], User.MOCK_USERS[17]]
//            case "7":
//                return [User.MOCK_USERS[6], User.MOCK_USERS[13]]
//            case "8":
//                return [User.MOCK_USERS[2], User.MOCK_USERS[18], User.MOCK_USERS[19], User.MOCK_USERS[20], User.MOCK_USERS[21], User.MOCK_USERS[22]]
//            default:
//                return []
//            }
//        }
//    }
//    
//    static func fetchAllUsers() -> [User] {
//        return User.MOCK_USERS
//    }
//    
//}
//
//// MARK: Profile
//extension UserService {
//    static func fetchUserCollections(id: String) -> [ClCollection] {
//        switch id {
//        case "1":
//            return [ClCollection.MOCK_COLLECTIONS[0], ClCollection.MOCK_COLLECTIONS[1], ClCollection.MOCK_COLLECTIONS[2]]
//        case "2":
//            return []
//        case "3":
//            return []
//        case "4":
//            return []
//        case "5":
//            return [ClCollection.MOCK_COLLECTIONS[0]]
//        case "6":
//            return [ClCollection.MOCK_COLLECTIONS[2], ClCollection.MOCK_COLLECTIONS[1]]
//        default:
//            return []
//        }
//    }
//}
