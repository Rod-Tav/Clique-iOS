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
        // Only update numFlicks if it increases, or if it's reasonable based on current images
        // This prevents backend returning 0 from overwriting optimistic updates during pending uploads
        if collection.numFlicks > existingCollection.numFlicks {
            existingCollection.numFlicks = collection.numFlicks
        } else if collection.numFlicks >= existingCollection.images.count {
            // Backend says it's less, but at least as many as images we have - trust it
            existingCollection.numFlicks = collection.numFlicks
        }
        // Otherwise keep existing numFlicks (protects pending uploads)
        if forceUpdateURL || shouldUpdatePhotoUrls(existingCollection.coverPhoto, collection.coverPhoto) {
            existingCollection.coverPhoto = collection.coverPhoto
        }
        if existingCollection.visibility != collection.visibility {
            existingCollection.visibility = collection.visibility
        }
        // TODO: better handling because images could be deleted. currently when collections are loaded on user profile they don't have images which is why this is here (so feed items keep their images)
        if existingCollection.images.count < collection.images.count {
            existingCollection.images = collection.images
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
    
    /// Optimistically increment numFlicks for a collection (used when starting uploads)
    func incrementFlickCount(collectionId: String, by count: Int) {
        guard var collection = collections[collectionId] else { return }
        collection.numFlicks += count
        collections[collectionId] = collection
    }

    func reset() {
        collections = [String: ClCollection]()
    }
}
