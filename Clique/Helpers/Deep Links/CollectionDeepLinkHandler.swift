//
//  CollectionDeepLinkHandler.swift
//  Clique
//
//  Created by Claude Code
//

import Foundation
import SwiftUI
import FirebaseAuth

/// Handles fetching and navigation for collection deep links
///
/// Deep link format: `clique://collection/{collectionId}`
@MainActor
class CollectionDeepLinkHandler {
    /// Enum representing the result of attempting to load a collection via deep link
    enum CollectionDeepLinkResult: Hashable {
        case success(collection: ClCollection)
        case notAuthenticated
        case notFound
        case networkError
    }

    /// Fetches a collection by ID and returns the appropriate result
    /// - Parameters:
    ///   - collectionId: The UUID of the collection to fetch
    ///   - collectionStore: The store to update with the fetched collection
    ///   - collectionImageStore: The store to update with collection images
    /// - Returns: A CollectionDeepLinkResult indicating success or the type of error
    static func fetchCollection(
        collectionId: String,
        collectionStore: CollectionStore,
        collectionImageStore: CollectionImageStore
    ) async -> CollectionDeepLinkResult {
        // Check authentication
        guard Auth.auth().currentUser != nil else {
            return .notAuthenticated
        }

        // Attempt to fetch the collection
        do {
            let input = Operations.getCollectionById.Input(
                path: .init(collectionDataId: collectionId),
                query: .init(page: 0, size: 1, sort: .DATEASC)
            )

            let collection = try await CollectionService.getCollectionById(input)

            // Update stores with the fetched collection
            await MainActor.run {
                collectionStore.updateCollection(collection, forceUpdateURL: true, collectionImageStore)
            }

            return .success(collection: collection)

        } catch {
            // Distinguish between network errors and API errors
            if error is URLError {
                // Network connectivity issues
                return .networkError
            } else if let serviceError = error as? ServiceError {
                switch serviceError {
                case .userNotAuthenticated:
                    return .notAuthenticated
                default:
                    // API returned an error (404, 400, 500, etc.)
                    // Since the API returns 404 for both "not found" and "no access",
                    // we treat all API errors as "not found"
                    return .notFound
                }
            } else {
                // Unknown error, treat as network error
                return .networkError
            }
        }
    }
}
