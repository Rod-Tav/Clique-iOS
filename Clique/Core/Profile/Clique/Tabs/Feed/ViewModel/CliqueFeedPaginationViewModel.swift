//
//  CliqueRecentsViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/22/24.
//

import Foundation

@Observable final class CliqueFeedPaginationViewModel: PaginationViewModel {
    typealias Item = FeedItem
    typealias Input = CliquePaginationFetchInput
    
    var items: [FeedItem] = []
    private var cid: String
    
    var page: Int = 0
    var size: Int { 5 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CliquePaginationFetchInput) async throws -> [FeedItem]
    
    init(cid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.cid = cid
        self.fetchFunction = { input in
            let feedItems = try await FeedService.fetchCliqueFeed(.init(path: .init(cliqueId: input.cid), query: .init(page: input.page, size: input.size)))
            
            await collectionStore.updateCollections(feedItems.compactMap({ $0.collection }), collectionImageStore)
            await cliqueStore.updateCliques(feedItems.compactMap({ $0.clique }))
            await userStore.updateUsers(feedItems.compactMap({ $0.relevantUser }))

            // Prefetch images for collections in the feed using grid context
            for feedItem in feedItems {
                if let collection = feedItem.collection {
                    CollectionImagePrefetcher.instance.prefetchForContext(
                        .gridView,  // Using grid context for clique feed thumbnails
                        collectionId: collection.id,
                        images: collection.images
                    )
                }
            }
            
            return feedItems
        }
    }
    
    func makeInput(page: Int, size: Int) -> CliquePaginationFetchInput {
        return CliquePaginationFetchInput(cid: cid, page: page, size: size)
    }
}
