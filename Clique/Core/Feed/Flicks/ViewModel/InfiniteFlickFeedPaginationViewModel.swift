//
//  InfiniteFlickFeedPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/26/25.
//

import Foundation

struct InfiniteFeedCursor: Codable {
    let seed: Int
    let id: String?
}

fileprivate func encodeCursorToBase64(_ cursor: InfiniteFeedCursor) -> String? {
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(cursor) {
        return jsonData.base64EncodedString()
    }
    return nil
}

@Observable final class InfiniteFlickFeedPaginationViewModel: PaginationViewModel {
    typealias Item = InfiniteFeedItem
    typealias Input = EmptyPaginationFetchInput
    
    var items: [InfiniteFeedItem] = []
    
    var page: Int = 0
    var size: Int { 25 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [InfiniteFeedItem]
    
    var seed: Int
    var first: Bool = true
    var curCursor: String = ""
    
    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.seed = Int(Int32.random(in: Int32.min...Int32.max))
        
        self.fetchFunction = { input in
            if self.first {
                let cursor = InfiniteFeedCursor(seed: self.seed, id: nil)
                
                if let encodedCursor = encodeCursorToBase64(cursor) {
                    let feedItemsRes = try await FeedService.fetchFlickFeed(.init(query: .init(cursor: encodedCursor)))
                    
                    let feedItems = feedItemsRes.0
                    
                    // Use grid view context for initial load - lighter prefetching
                    CollectionImagePrefetcher.instance.prefetchForContext(
                        .gridView,
                        collectionId: String(self.seed),
                        images: feedItems.compactMap({ $0.flick })
                    )
                    
                    await collectionStore.updateCollections(feedItems.compactMap({ $0.collection }), collectionImageStore)
                    await collectionImageStore.updateImages(feedItems.compactMap({ $0.flick }))
                    await cliqueStore.updateCliques(feedItems.compactMap({ $0.clique }))
                    await userStore.updateUsers(feedItems.compactMap({ $0.flick.owner }))
                    await userStore.updateUsers(feedItems.flatMap({ $0.cliqueMembers }))
                    
                    self.curCursor = feedItemsRes.1
                    self.first = false
                    
                    return feedItems
                }
            } else {
                let feedItemsRes = try await FeedService.fetchFlickFeed(.init(query: .init(cursor: self.curCursor)))
                
                let feedItems = feedItemsRes.0
                
                // Use grid context for subsequent pages - much lighter prefetching
                CollectionImagePrefetcher.instance.prefetchForContext(
                    .gridView,
                    collectionId: String(self.seed),
                    images: feedItems.compactMap({ $0.flick })
                )
                
                await collectionStore.updateCollections(feedItems.compactMap({ $0.collection }), collectionImageStore)
                await collectionImageStore.updateImages(feedItems.compactMap({ $0.flick }))
                await cliqueStore.updateCliques(feedItems.compactMap({ $0.clique }))
                await userStore.updateUsers(feedItems.compactMap({ $0.flick.owner }))
                await userStore.updateUsers(feedItems.flatMap({ $0.cliqueMembers }))
                
                self.curCursor = feedItemsRes.1
                
                return feedItems
            }
            
            return []
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        return EmptyPaginationFetchInput(page: page, size: size)
    }
}
