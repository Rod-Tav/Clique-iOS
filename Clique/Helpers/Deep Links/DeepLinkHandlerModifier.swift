//
//  DeepLinkHandlerModifier.swift
//  Clique
//
//  Created by Claude Code
//

import SwiftUI

/// ViewModifier that handles deep link navigation throughout the app
///
/// Supported URL formats:
/// - Collection: `clique://collection/{collectionId}`
/// - Example: `clique://collection/550e8400-e29b-41d4-a716-446655440000`
struct DeepLinkHandlerModifier: ViewModifier {
    /// Tab navigation coordinator for managing navigation state
    let tabViewCoordinator: TabViewCoordinator

    /// Collection metadata store
    let collectionStore: CollectionStore

    /// Collection images store
    let collectionImageStore: CollectionImageStore

    /// Collection ID from deep link to navigate to
    @State private var pendingCollectionId: String?

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: pendingCollectionId) { oldValue, newValue in
                handleCollectionNavigation(collectionId: newValue)
            }
    }

    // MARK: - Deep Link Parsing

    /// Handles incoming deep link URLs
    /// - Parameter url: The URL to parse and handle
    private func handleDeepLink(_ url: URL) {
        let deeplinkManager = DeepLinkManager()
        let deeplink = deeplinkManager.manage(url)

        switch deeplink {
        case .home:
            break

        case .details:
            break

        case .collection(let collectionId):
            // Set the pending collection ID to trigger navigation via onChange
            pendingCollectionId = collectionId
        }
    }

    // MARK: - Collection Navigation

    /// Handles navigation to a collection when a collection ID is set
    /// - Parameter collectionId: The collection ID to navigate to, or nil to clear
    private func handleCollectionNavigation(collectionId: String?) {
        guard let collectionId = collectionId else { return }

        Task {
            let result = await CollectionDeepLinkHandler.fetchCollection(
                collectionId: collectionId,
                collectionStore: collectionStore,
                collectionImageStore: collectionImageStore
            )

            await MainActor.run {
                switch result {
                case .success(let collection):
                    navigateToCollection(collection)

                case .notAuthenticated:
                    navigateToError(.notAuthenticated)

                case .notFound:
                    navigateToError(.notFound)

                case .networkError:
                    navigateToError(.networkError(collectionId: collectionId))
                }
            }
        }
    }

    /// Navigates to the collection detail view
    /// - Parameter collection: The collection to navigate to
    private func navigateToCollection(_ collection: ClCollection) {
        // Clear profile navigation path and switch to profile tab
        tabViewCoordinator.profileNavigationPath = NavigationPath()
        tabViewCoordinator.activeTab = .profile

        // Navigate to CollectionMainView after tab switch completes
        Task { @MainActor in
            // Brief delay to ensure tab switch has completed
            try? await Task.sleep(for: .milliseconds(300))

            tabViewCoordinator.navigate(to: collection)
            pendingCollectionId = nil // Clear pending state
        }
    }

    /// Navigates to an error destination
    /// - Parameter destination: The error destination enum
    private func navigateToError(_ destination: CollectionDeepLinkDestination) {
        // Clear profile navigation path and switch to profile tab
        tabViewCoordinator.profileNavigationPath = NavigationPath()
        tabViewCoordinator.activeTab = .profile

        // Navigate to error view after tab switch completes
        Task { @MainActor in
            // Brief delay to ensure tab switch has completed
            try? await Task.sleep(for: .milliseconds(300))

            tabViewCoordinator.navigate(to: destination)
            pendingCollectionId = nil
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies deep link handling to a view
    ///
    /// This modifier enables the view to respond to deep links and navigate accordingly.
    ///
    /// ## Usage
    /// ```swift
    /// TabView {
    ///     // tabs...
    /// }
    /// .handleDeepLinks(
    ///     tabViewCoordinator: coordinator,
    ///     collectionStore: collectionStore,
    ///     collectionImageStore: collectionImageStore
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - tabViewCoordinator: The tab coordinator for navigation
    ///   - collectionStore: The collection metadata store
    ///   - collectionImageStore: The collection images store
    /// - Returns: View configured with deep link handling
    func handleDeepLinks(
        tabViewCoordinator: TabViewCoordinator,
        collectionStore: CollectionStore,
        collectionImageStore: CollectionImageStore
    ) -> some View {
        modifier(DeepLinkHandlerModifier(
            tabViewCoordinator: tabViewCoordinator,
            collectionStore: collectionStore,
            collectionImageStore: collectionImageStore
        ))
    }
}
