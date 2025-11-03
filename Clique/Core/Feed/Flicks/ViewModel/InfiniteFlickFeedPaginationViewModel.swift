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
    let offset: Int
    let pageSize: Int
    let chunkSize: Int
    let dateCreated: String?
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

    // Grid column preference - updated from view
    var gridColumns: Int = 3

    // Batch size for grid view - number of items to fetch per page
    // Dynamically calculated based on grid columns:
    // 4 columns -> 28 items, 3 columns -> 15 items, 2 columns -> 8 items
    private var batchSize: Int {
        switch gridColumns {
        case 4: return 28
        case 3: return 15
        case 2: return 8
        default: return 15 // fallback to default
        }
    }
    var size: Int { batchSize }

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
    // Track if the cursor indicates no more items
    var hasMoreItems: Bool = true
    
    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.seed = Int(Int32.random(in: Int32.min...Int32.max))

        self.fetchFunction = { input in
            let cursor: String

            if self.first {
                let cursorData = InfiniteFeedCursor(
                    seed: self.seed,
                    id: nil,
                    offset: 0,
                    pageSize: self.batchSize,
                    chunkSize: 100,
                    dateCreated: nil
                )

                guard let encodedCursor = encodeCursorToBase64(cursorData) else {
                    return []
                }
                cursor = encodedCursor
            } else {
                cursor = self.curCursor
            }

            // Make a single request with the proper pageSize
            let feedItemsRes = try await FeedService.fetchFlickFeed(.init(query: .init(cursor: cursor)))
            let feedItems = feedItemsRes.0
            let newCursor = feedItemsRes.1

            // Use grid view context for prefetching
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

            self.curCursor = newCursor
            self.first = false

            return feedItems
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        return EmptyPaginationFetchInput(page: page, size: size)
    }

    // Override fetchItems to handle cursor-based pagination properly
    @MainActor
    func fetchItems(input: Input, refresh: Bool = false) async throws {
        if refresh {
            // Reset for refresh
            refreshTask?.cancel()
            refreshTask = Task { @MainActor in
                guard !isRefreshing else { return }
                isRefreshing = true
                defer { isRefreshing = false }

                let requestId = UUID()
                latestRequestId = requestId

                do {
                    // Reset state
                    first = true
                    seed = Int(Int32.random(in: Int32.min...Int32.max))
                    hasMoreItems = true

                    let newItems = try await fetchFunction(input)

                    guard latestRequestId == requestId else { return }

                    items = newItems
                    page = 0
                    // For cursor-based pagination, check if we got any items
                    // If we get 0 items, we're done. Otherwise keep going.
                    done = newItems.isEmpty || !hasMoreItems
                    page = 1
                } catch {
                    if !(error is CancellationError) {
                        throw error
                    }
                }
            }
            try await refreshTask?.value
        } else {
            // Regular pagination
            guard !done else { return }

            let requestId = UUID()
            latestRequestId = requestId

            let newItems = try await fetchFunction(input)

            guard latestRequestId == requestId else { return }

            // For cursor-based pagination with batching:
            // We're done when we get fewer than batchSize items
            // (means backend ran out of data while trying to accumulate batchSize)
            done = newItems.count < batchSize

            items.append(contentsOf: newItems)
            page += 1
        }
    }
}
