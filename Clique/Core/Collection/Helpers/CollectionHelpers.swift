//
//  CollectionHelpers.swift
//  Clique
//
//  Created by Rod Tavangar on 3/1/25.
//

import Foundation

@MainActor func handleCollectionImageLikeTapped(image: CollectionImage, _ collectionImageStore: CollectionImageStore) throws {
//    if let image = selectedImage, let selectedImageId {
    collectionImageStore.images[image.id]?.hasLiked.toggle()
        let oldNumLikes = image.numLikes
        
        Task {
            do {
                // this is reversed because it's if let image
                if image.hasLiked {
                    collectionImageStore.images[image.id]?.numLikes -= 1
                    try await CollectionService.unlikeCollectionItem(.init(path: .init(collectionItemId: image.id)))
                } else {
                    collectionImageStore.images[image.id]?.numLikes += 1
                    try await CollectionService.likeCollectionItem(.init(path: .init(collectionItemId: image.id)))
                }
            } catch {
                collectionImageStore.images[image.id]?.hasLiked.toggle()
                collectionImageStore.images[image.id]?.numLikes = oldNumLikes
                throw error
            }
        }
//    }
}
