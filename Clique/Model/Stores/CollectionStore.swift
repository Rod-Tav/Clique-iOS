//
//  CollectionStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/24/25.
//

import Foundation

/// Observable store managing collection metadata throughout the app lifecycle.
///
/// This store provides centralized collection data management with intelligent URL refresh,
/// partial updates, and coordination with ``CollectionImageStore`` for image data.
///
/// ## Key Features
/// - **Smart URL Management**: Automatic detection of expired S3 URLs for cover photos
/// - **Partial Updates**: Only updates changed fields to prevent unnecessary UI refreshes
/// - **Image Coordination**: Automatically updates ``CollectionImageStore`` with collection images
/// - **Force Update Support**: Can bypass smart checking when needed (e.g., manual refresh)
///
/// ## URL Management
/// Collections have cover photos (static images) that use S3 presigned URLs with expiration.
/// The store uses `shouldUpdatePhotoUrls()` to check if cover photo URLs need refreshing.
///
/// For Live Photos and Videos within collections, URL management is handled by
/// ``CollectionImageStore`` which checks both photo and video URL expiration independently.
///
/// ## Usage
/// ```swift
/// @Environment(CollectionStore.self) private var collectionStore
/// @Environment(CollectionImageStore.self) private var collectionImageStore
///
/// // Update collection (smart URL checking)
/// collectionStore.updateCollection(collection, collectionImageStore)
///
/// // Force URL refresh (bypass expiration checking)
/// collectionStore.updateCollection(collection, forceUpdateURL: true, collectionImageStore)
/// ```
@Observable @MainActor final class CollectionStore {
    var collections = [String: ClCollection]() // id to collection
    
    func updateCollection(_ collection: ClCollection, forceUpdateURL: Bool = false, _ collectionImageStore: CollectionImageStore) {
        guard var existingCollection = collections[collection.id] else {
            collections[collection.id] = collection // If collection doesn't exist, add it directly
            collectionImageStore.updateImages(collection.images)
            return
        }
        
        // Update only fields that have changed
        if existingCollection.name != collection.name {
            existingCollection.name = collection.name
        }
        if existingCollection.description != collection.description {
            existingCollection.description = collection.description
        }
        if existingCollection.cliqueId != collection.cliqueId {
            existingCollection.cliqueId = collection.cliqueId
        }

        // Update numFlicks from backend, but protect against the 0 edge case during uploads
        // Backend returns 0 when no flicks are processed yet, but we might have PENDING uploads
        if collection.numFlicks == 0 && !existingCollection.images.isEmpty {
            // Keep existing numFlicks if backend says 0 but we have images locally
            // displayFlickCount() will handle the actual count with PENDING items
        } else {
            // Trust backend's numFlicks in all other cases
            existingCollection.numFlicks = collection.numFlicks
        }
        if forceUpdateURL || shouldUpdatePhotoUrls(existingCollection.coverPhoto, collection.coverPhoto) {
            existingCollection.coverPhoto = collection.coverPhoto
        }
        if existingCollection.visibility != collection.visibility {
            existingCollection.visibility = collection.visibility
        }

        // Update images array when backend provides data
        // Some API endpoints return collections without images (e.g., profile collection list)
        if !collection.images.isEmpty || forceUpdateURL {
            // Preserve local PENDING images that aren't in the backend response yet
            // During refresh, backend might not include PENDING images, but we want to keep showing them
            let localPendingImages = existingCollection.images.filter { localImage in
                localImage.uploadStatus == .PENDING &&
                !collection.images.contains(where: { $0.id == localImage.id })
            }

            // Merge: backend images + preserved local PENDING images
            existingCollection.images = collection.images + localPendingImages
        }
        
        if collection.mostLikedImage != nil {
            existingCollection.mostLikedImage = collection.mostLikedImage
            if collection.mostLikedImage == "002aa12d-fb9f-4433-88e0-9c1671f6ebe6" {
               // TODO: figure out print(collection.mostLikedImage)
            }
        }
        
        collectionImageStore.updateImages(collection.images, forceUpdateURLs: forceUpdateURL)
        
        collections[collection.id] = existingCollection
    }
    
    func updateCollections(_ newCollections: [ClCollection], forceUpdateURLs: Bool = false, _ collectionImageStore: CollectionImageStore) {
        newCollections.forEach { updateCollection($0, forceUpdateURL: forceUpdateURLs, collectionImageStore) }
    }

    func reset() {
        collections = [String: ClCollection]()
    }
}
