//
//  MostLikedImageFetcher.swift
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//

import SwiftUI

struct FetchMostLikedImageModifier: ViewModifier {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    var collectionId: String?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    do {
                        try await fetchMostLikedImage(collectionId: collectionId, collectionStore, collectionImageStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
    }
}

extension View {
    func fetchMostLikedImage(collectionId: String?) -> some View {
        self.modifier(FetchMostLikedImageModifier(collectionId: collectionId))
    }
}

private func fetchMostLikedImage(collectionId: String?, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) async throws {
    guard let collectionId, await collectionStore.collections[collectionId]?.mostLikedImage == nil else { return }
    
    var collectionMostLiked = try await CollectionService.getCollectionById(.init(path: .init(collectionDataId: collectionId), query: .init(page: 0, size: 1, sort: .LIKESASC)))
    
    if collectionId == "4b0cdee6-310d-4fa2-97ef-4a2407c2a69a" {
       // TODO: figure out print("hello")
//        print(collectionMostLiked.images.first?.id)
        // 0746654b-c2f3-4673-9413-7b503a125aa3
        // 002aa12d-fb9f-4433-88e0-9c1671f6ebe6
    }
    
    collectionMostLiked.mostLikedImage = collectionMostLiked.images.first?.id
    
    await collectionStore.updateCollection(collectionMostLiked, collectionImageStore)
}
