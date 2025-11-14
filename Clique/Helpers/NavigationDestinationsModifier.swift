//
//  NavigationDestinationsModifier.swift
//  Clique
//
//  Created by Rod Tavangar on 11/18/24.
//

import Foundation
import SwiftUI

/// Central navigation destination registry for type-safe navigation throughout the app.
///
/// This modifier defines all global navigation destinations that can be accessed
/// from any tab in the app using value-based navigation. It eliminates the need
/// for string-based navigation and provides compile-time safety.
///
/// ## Architecture
/// The modifier leverages SwiftUI's `navigationDestination(for:)` to create
/// type-safe navigation mappings. Each domain model type (User, Clique, etc.)
/// maps to its corresponding view.
///
/// ## Usage
/// Apply this modifier to tab navigation stacks using the convenience extension:
/// ```swift
/// TabNavigationStack(path: $coordinator.flicksNavigationPath) {
///     FlicksFeedView()
/// }
/// .rootNavigationDestinations()  // Applies this modifier
/// ```
///
/// ## Navigation Examples
/// ```swift
/// // Navigate to a user profile
/// coordinator.navigate(to: user)
/// 
/// // Navigate to a clique
/// NavigationLink(value: clique) { CliqueRowView(clique) }
/// 
/// // Navigate to special views using strings
/// coordinator.navigate(to: "UserSettings")
/// ```
///
/// - Important: Only use with `TabNavigationStack`, never with `CreateNavigationStack`
/// - Warning: Nesting NavigationStacks will cause NavigationRequestObserver errors
struct NavigationDestinationsModifier: ViewModifier {
    /// User data store for passing to views that need user information
    @Environment(UserStore.self) private var userStore
    /// Clique data store for clique-related views
    @Environment(CliqueStore.self) private var cliqueStore
    /// Collection metadata store
    @Environment(CollectionStore.self) private var collectionStore
    /// Individual collection images store
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    func body(content: Content) -> some View {
        content
            // MARK: - Domain Model Destinations
            
            /// Navigate to user profiles using User model
            .navigationDestination(for: User.self) { user in
                UserProfileTabsView(userId: user.id)
                    .navigationBarBackButtonHidden()
            }
            
            /// Navigate to followers/following lists using enum
            .navigationDestination(for: FollowersFollowing.self) { followersFollowing in
                switch followersFollowing {
                case .followers(let user):
                    FollowersFollowingView(uid: user.id, userStore: userStore)
                        .navigationBarBackButtonHidden()
                case .following(let user):
                    FollowersFollowingView(uid: user.id, selectedTab: 1, userStore: userStore)
                        .navigationBarBackButtonHidden()
                }
            }
            
            /// Navigate to clique profiles using Clique model
            .navigationDestination(for: Clique.self) { clique in
                CliqueProfileView(cid: clique.id)
                    .navigationBarBackButtonHidden()
            }
            
            /// Navigate to collection detail views using ClCollection model
            .navigationDestination(for: ClCollection.self) { collection in
                CollectionMainView(collectionId: collection.id, cliqueId: collection.cliqueId, collectionStore, collectionImageStore)
                    .navigationBarBackButtonHidden()
            }

            /// Navigate to collection deep link error states
            .navigationDestination(for: CollectionDeepLinkDestination.self) { destination in
                Group {
                    switch destination {
                    case .networkError(let collectionId):
                        CollectionRetryView(collectionId: collectionId)
                    case .notFound:
                        CollectionErrorStateView(
                            iconName: "photo.on.rectangle.angled",
                            title: "Collection Not Found",
                            message: "This collection doesn't exist or may have been deleted"
                        )
                    case .accessDenied:
                        CollectionErrorStateView(
                            iconName: "lock.circle.fill",
                            title: "No Access",
                            message: "You don't have access to this collection"
                        )
                    case .notAuthenticated:
                        CollectionErrorStateView(
                            iconName: "photo.on.rectangle.angled",
                            title: "Collection Not Found",
                            message: "This collection doesn't exist or may have been deleted"
                        )
                    }
                }
                .navigationBarBackButtonHidden()
            }

            // MARK: - String-Based Special Destinations

            /// Special app views accessed by string identifiers
            /// - Note: Prefer domain models over strings when possible
            .navigationDestination(for: String.self) { string in
                Group {
                    if string == "UserSettings" {
                        UserSettingsView()
                    } else if string == "Search" {
                        VStack(spacing: 0) {
                            SearchView(userStore)
                        }
                    } else if string == "CurrentUser" {
                        CurrentUserProfileView()
                    } else if string == "NotificationsCenter" {
                        NotificationsCenterView(userStore, cliqueStore, collectionStore, collectionImageStore)
                    }
                }
                .navigationBarBackButtonHidden()
            }
    }
}

// MARK: - Private Helper Views

/// Private helper view that handles retry logic for collection network errors
private struct CollectionRetryView: View {
    @Environment(TabViewCoordinator.self) private var coordinator
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore

    let collectionId: String
    @State private var isRetrying = false
    @State private var retryTask: Task<Void, Never>?

    var body: some View {
        CollectionErrorStateView(
            iconName: "exclamationmark.triangle.fill",
            title: "Unable to Load Collection",
            message: "There was a problem loading this collection. Please check your connection and try again.",
            retryAction: {
                guard !isRetrying else { return }

                // Cancel any existing retry task
                retryTask?.cancel()

                isRetrying = true

                retryTask = Task {
                    let result = await CollectionDeepLinkHandler.fetchCollection(
                        collectionId: collectionId,
                        collectionStore: collectionStore,
                        collectionImageStore: collectionImageStore
                    )

                    // Check if task was cancelled
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        isRetrying = false

                        // Navigate based on result
                        coordinator.profileNavigationPath.removeLast()

                        switch result {
                        case .success(let collection):
                            coordinator.navigate(to: collection)
                        case .notAuthenticated:
                            coordinator.navigate(to: CollectionDeepLinkDestination.notAuthenticated)
                        case .notFound:
                            coordinator.navigate(to: CollectionDeepLinkDestination.notFound)
                        case .networkError:
                            coordinator.navigate(to: CollectionDeepLinkDestination.networkError(collectionId: collectionId))
                        }
                    }
                }
            }
        )
    }
}

// MARK: - View Extension

extension View {
    /// Applies global navigation destinations to a view.
    ///
    /// Use this modifier on tab navigation stacks to enable type-safe navigation
    /// to all major app destinations.
    ///
    /// ## Usage
    /// ```swift
    /// TabNavigationStack(path: $coordinator.flicksNavigationPath) {
    ///     FlicksFeedView()
    /// }
    /// .rootNavigationDestinations()
    /// ```
    ///
    /// - Returns: View configured with all global navigation destinations
    /// - Important: Only use with main tab navigation stacks, not create flow stacks
    func rootNavigationDestinations() -> some View {
        modifier(NavigationDestinationsModifier())
    }
}
