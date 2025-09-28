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

    // Batch size for grid view - fetches multiple backend pages to reach this count
    private let batchSize = 35
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
            // Accumulate items until we have 25 or run out
            var accumulatedItems: [InfiniteFeedItem] = []
            var tempCursor: String = ""

            if self.first {
                let cursor = InfiniteFeedCursor(seed: self.seed, id: nil)

                if let encodedCursor = encodeCursorToBase64(cursor) {
                    tempCursor = encodedCursor

                    // Keep fetching until we have batchSize items or no more data
                    while accumulatedItems.count < self.batchSize {
                        let feedItemsRes = try await FeedService.fetchFlickFeed(.init(query: .init(cursor: tempCursor)))
                        let feedItems = feedItemsRes.0

                        if feedItems.isEmpty {
                            // No more items available
                            break
                        }

                        accumulatedItems.append(contentsOf: feedItems)
                        tempCursor = feedItemsRes.1

                        // If we got less than 10 items, we're at the end
                        if feedItems.count < 10 {
                            break
                        }
                    }

                    // Trim to exactly batchSize if we got more
                    if accumulatedItems.count > self.batchSize {
                        accumulatedItems = Array(accumulatedItems.prefix(self.batchSize))
                    }

                    // Use grid view context for initial load - lighter prefetching
                    CollectionImagePrefetcher.instance.prefetchForContext(
                        .gridView,
                        collectionId: String(self.seed),
                        images: accumulatedItems.compactMap({ $0.flick })
                    )

                    await collectionStore.updateCollections(accumulatedItems.compactMap({ $0.collection }), collectionImageStore)
                    await collectionImageStore.updateImages(accumulatedItems.compactMap({ $0.flick }))
                    await cliqueStore.updateCliques(accumulatedItems.compactMap({ $0.clique }))
                    await userStore.updateUsers(accumulatedItems.compactMap({ $0.flick.owner }))
                    await userStore.updateUsers(accumulatedItems.flatMap({ $0.cliqueMembers }))

                    self.curCursor = tempCursor
                    self.first = false

                    return accumulatedItems
                }
            } else {
                // For subsequent fetches, also accumulate to batchSize
                tempCursor = self.curCursor

                while accumulatedItems.count < self.batchSize {
                    let feedItemsRes = try await FeedService.fetchFlickFeed(.init(query: .init(cursor: tempCursor)))
                    let feedItems = feedItemsRes.0

                    if feedItems.isEmpty {
                        // No more items available
                        break
                    }

                    accumulatedItems.append(contentsOf: feedItems)
                    tempCursor = feedItemsRes.1

                    // If we got less than 10 items, we're at the end
                    if feedItems.count < 10 {
                        break
                    }
                }

                // Trim to exactly batchSize if we got more
                if accumulatedItems.count > self.batchSize {
                    accumulatedItems = Array(accumulatedItems.prefix(self.batchSize))
                }

                // Use grid context for subsequent pages - much lighter prefetching
                CollectionImagePrefetcher.instance.prefetchForContext(
                    .gridView,
                    collectionId: String(self.seed),
                    images: accumulatedItems.compactMap({ $0.flick })
                )

                await collectionStore.updateCollections(accumulatedItems.compactMap({ $0.collection }), collectionImageStore)
                await collectionImageStore.updateImages(accumulatedItems.compactMap({ $0.flick }))
                await cliqueStore.updateCliques(accumulatedItems.compactMap({ $0.clique }))
                await userStore.updateUsers(accumulatedItems.compactMap({ $0.flick.owner }))
                await userStore.updateUsers(accumulatedItems.flatMap({ $0.cliqueMembers }))

                self.curCursor = tempCursor

                return accumulatedItems
            }

            return []
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
