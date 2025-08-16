//
//  CollectionStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/24/25.
//

import Foundation

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
        if existingCollection.numFlicks != collection.numFlicks {
            existingCollection.numFlicks = collection.numFlicks
        }
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
    
    func reset() {
        collections = [String: ClCollection]()
    }
}
