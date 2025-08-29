//
//  FeedViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/27/24.
//

import SwiftUI
import Combine

@Observable final class HomeFeedPaginationViewModel: PaginationViewModel {
    typealias Item = FeedItem
    typealias Input = EmptyPaginationFetchInput
    
    var items: [FeedItem] = [] {
        didSet {
            // Notify observers when items change for UIKit integration
            itemsDidChange.send(items)
        }
    }
    
    var page: Int = 0
    var size: Int { 5 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    // Publisher for UIKit integration
    let itemsDidChange = PassthroughSubject<[FeedItem], Never>()
    
    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [FeedItem]
    
    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.fetchFunction = { input in
            let feedItems = try await FeedService.fetchFeedPosts(.init(query: .init(page: input.page, size: input.size)))
            
            await collectionStore.updateCollections(feedItems.compactMap({ $0.collection }), collectionImageStore)
            await cliqueStore.updateCliques(feedItems.compactMap({ $0.clique }))
            await userStore.updateUsers(feedItems.compactMap({ $0.relevantUser }))
            
            return feedItems
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        return EmptyPaginationFetchInput(page: page, size: size)
    }
}
