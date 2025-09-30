//
//  CollectionImageStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/24/25.
//

import Foundation

/// Observable store managing individual collection images (photos, Live Photos, videos) throughout the app lifecycle.
///
/// This store provides centralized image data management with intelligent URL refresh for both
/// photo and video components, partial updates, and S3 URL expiration handling.
///
/// ## Key Features
/// - **Dual URL Management**: Separate smart checking for photo URLs and video URLs
/// - **Live Photo Support**: Tracks both still image URLs and video component URLs
/// - **Partial Updates**: Only updates changed fields to prevent unnecessary UI refreshes
/// - **S3 Expiration Handling**: Automatically detects expired presigned URLs
/// - **Force Update Support**: Can bypass smart checking when needed (e.g., manual refresh)
///
/// ## URL Management Strategy
/// Collection images can have two types of URLs:
/// - **Photo URLs** (`imageUrl`): Three quality levels (high/med/low) for still images
/// - **Video URLs** (`videoUrls`): Full resolution video for Live Photos
///
/// Both URL types are checked independently for expiration. The store uses:
/// - `shouldUpdatePhotoUrls()` for photo component URLs
/// - `shouldUpdateVideoUrls()` for video component URLs (Live Photos only)
///
/// ## MediaType Support
/// - **PHOTO**: Regular photos (imageUrl only)
/// - **LIVE**: Live Photos (imageUrl + videoUrls)
/// - **VIDEO**: Videos (videoUrls only, imageUrl may contain thumbnail)
///
/// ## Usage
/// ```swift
/// @Environment(CollectionImageStore.self) private var collectionImageStore
///
/// // Update single image (smart URL checking)
/// collectionImageStore.updateImage(image)
///
/// // Force URL refresh for all images
/// collectionImageStore.updateImages(images, forceUpdateURLs: true)
///
/// // Batch update multiple images
/// collectionImageStore.updateImages(newImages)
/// ```
///
/// ## URL Expiration
/// S3 presigned URLs typically expire after 1 hour. The store automatically detects
/// expired URLs by checking the `X-Amz-Date` parameter in the URL query string.
/// If an image's URLs have expired, new URLs from the API will be used even if
/// the base file path hasn't changed.
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
        // Update video URLs with same smart checking for Live Photos
        if forceUpdateURL || shouldUpdateVideoUrls(existingImage.videoUrls, image.videoUrls) {
            existingImage.videoUrls = image.videoUrls
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
