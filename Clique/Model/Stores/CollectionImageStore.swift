//
//  CollectionImageStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/24/25.
//

import Foundation

@Observable @MainActor final class CollectionImageStore {
    var images = [String: CollectionImage]() // id to CollectionImage
    
    func updateImage(_ image: CollectionImage, forceUpdateURL: Bool = false) {
        guard var existingImage = images[image.id] else {
            images[image.id] = image // If image doesn't exist, add it directly
            return
        }
        
        // Update only fields that have changed
        if forceUpdateURL || shouldUpdatePhotoUrls(existingImage.imageUrl, image.imageUrl) {
            existingImage.imageUrl = image.imageUrl
        }
        if existingImage.date != image.date {
            existingImage.date = image.date
        }
        if existingImage.numLikes != image.numLikes {
            existingImage.numLikes = image.numLikes
        }
        if existingImage.numComments != image.numComments {
            existingImage.numComments = image.numComments
        }
        if existingImage.numTaggedMembers != image.numTaggedMembers {
            existingImage.numTaggedMembers = image.numTaggedMembers
        }
        if existingImage.hasLiked != image.hasLiked {
            existingImage.hasLiked = image.hasLiked
        }
        
        images[image.id] = existingImage
    }
    
    func updateImages(_ newImages: [CollectionImage], forceUpdateURLs: Bool = false) {
        newImages.forEach { updateImage($0, forceUpdateURL: forceUpdateURLs) }
    }
    
    func reset() {
        images = [String: CollectionImage]()
    }
}
