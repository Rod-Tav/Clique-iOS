//
//  FlicksFeedPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/19/25.
//

import Foundation

struct FeedImageItem: Identifiable, Hashable {
    let id: String
    let collectionId: String
    let relevantUserId: String?
}

@Observable final class FlicksFeedPaginationViewModel: PaginationViewModel {
    typealias Item = FeedImageItem
    typealias Input = EmptyPaginationFetchInput
    
    // PaginationViewModel requirements
    var items: [FeedImageItem] = []
    var page: Int = 0
    var size: Int { imagesPerCollectionBatch * collectionsPerBatch }
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    // Backing fetch function
    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [FeedImageItem] = { _ in [] }
    
    // Custom state
    private var collectionPage = 0
    private var collectionIDs: [String] = []
    private var nextImagePage: [String: Int] = [:]
    private var collectionSort: [String: SortOption] = [:]
    private var buffer: [FeedImageItem] = []
    private let imagesPerCollectionBatch = 4
    private let collectionsPerBatch = 3
    
    
    
    // Track initial batch
    private var hasFetchedInitialBatch = false
    
    private let collectionStore: CollectionStore
    private let collectionImageStore: CollectionImageStore
    private let cliqueStore: CliqueStore
    private let userStore: UserStore
    
    // Concurrency throttle
    private let fetchSemaphore = AsyncSemaphore(value: 4)
    
    private var seenGlobalIDs: Set<String> = []
    private var imageToCollectionID: [String: String] = [:]
    private var collectionToRelevantUserId: [String: String?] = [:]
    
    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ cliqueStore: CliqueStore, _ userStore: UserStore) {
        self.collectionStore = collectionStore
        self.collectionImageStore = collectionImageStore
        self.cliqueStore = cliqueStore
        self.userStore = userStore
        
        fetchFunction = { [weak self] input in
            guard let self = self else { return [] }
            let newItems = try await self.loadNextImagePage(count: input.size)
            return newItems.uniqued()
        }
    }
    
    private func loadInitialCollections() async throws {
        let feed = try await FeedService.fetchFeedPosts(
            .init(query: .init(page: collectionPage, size: collectionsPerBatch))
        )
        
        await collectionStore.updateCollections(feed.compactMap({ $0.collection }), collectionImageStore)
        await cliqueStore.updateCliques(feed.compactMap({ $0.clique }))
        await userStore.updateUsers(feed.compactMap({ $0.relevantUser }))
        
        collectionPage += 1
        let ids = feed.compactMap { $0.collection?.id }
        collectionIDs.append(contentsOf: ids)
        ids.forEach {
            nextImagePage[$0] = 0
            collectionSort[$0] = SortOption.allCases.randomElement() ?? .timeDesc
        }
        
        // Build map from collection id to relevant user id
        for post in feed {
            if let collectionId = post.collection?.id {
                collectionToRelevantUserId[collectionId] = post.relevantUser?.id
            }
        }
    }
    
    /// Parallel then round-robin fetch to fill initial target
    private func initialFillBatch() async throws {
        while collectionIDs.count < collectionsPerBatch {
            try await loadInitialCollections()
            if collectionIDs.isEmpty { break }
        }
        
        let initialSubset = Array(collectionIDs.prefix(collectionsPerBatch)).shuffled()
        collectionIDs.replaceSubrange(0..<initialSubset.count, with: initialSubset)
        
        let targetCount = imagesPerCollectionBatch * collectionsPerBatch
        var i = 0
        
        while buffer.count < targetCount {
            if i >= collectionIDs.count {
                try await loadInitialCollections()
                i = 0
                if collectionIDs.isEmpty { break }
            }
            
            let cid = collectionIDs[i]
            guard let page = nextImagePage[cid] else {
                i += 1
                continue
            }
            
            let coll = try await CollectionService.getCollectionById(
                .init(
                    path: .init(collectionDataId: cid),
                    query: .init(
                        page: page,
                        size: imagesPerCollectionBatch,
                        sort: mapFromSortOption(collectionSort[cid] ?? .timeDesc)
                    )
                )
            )
            
            nextImagePage[cid]! += 1
            await collectionStore.updateCollection(coll, collectionImageStore)
            
            let relevantUserId = collectionToRelevantUserId[cid] ?? nil
            let items = coll.images.map { FeedImageItem(id: $0.id, collectionId: coll.id, relevantUserId: relevantUserId) }
            let newUnique = items.filter { seenGlobalIDs.insert($0.id).inserted }
            newUnique.forEach { imageToCollectionID[$0.id] = $0.collectionId }
            
            if newUnique.isEmpty {
                collectionIDs.removeAll { $0 == cid }
                nextImagePage.removeValue(forKey: cid)
            }
            i += 1
            
            if !newUnique.isEmpty {
                buffer.append(contentsOf: newUnique)
            }
        }
        
        buffer.shuffle()
    }
    
    /// Phase 1: fetch minimal for page; Phase 2: background refill
    private func loadNextImagePage(count: Int) async throws -> [FeedImageItem] {
        // Reset done
        done = false
        
        // Initial fill once
        if !hasFetchedInitialBatch {
            try await initialFillBatch()
            hasFetchedInitialBatch = true
        }
        
        while buffer.count < count && !done {
            try await fetchMoreImagesIntoBuffer()
        }
        
        let take = min(count, buffer.count)
        let pageItems = Array(buffer.prefix(take))
        buffer.removeFirst(take)
        
        // Background refill
        Task { try? await fetchMoreImagesIntoBuffer() }
        
        // Shuffle page items and return with collectionId mapping
        return pageItems.shuffled().map { FeedImageItem(id: $0.id, collectionId: imageToCollectionID[$0.id]!, relevantUserId: collectionToRelevantUserId[imageToCollectionID[$0.id]!] ?? nil) }
    }
    
    /// Refill buffer round-robin style
    private func fetchMoreImagesIntoBuffer() async throws {
        if collectionIDs.isEmpty {
            try await loadInitialCollections()
        }
        if collectionIDs.isEmpty && buffer.isEmpty {
            done = true
            return
        }
        
        for cid in collectionIDs {
            guard let page = nextImagePage[cid] else { continue }
            await fetchSemaphore.wait()
            defer { Task { await fetchSemaphore.signal() } }
            
            let coll = try await CollectionService.getCollectionById(
                .init(
                    path: .init(collectionDataId: cid),
                    query: .init(
                        page: page,
                        size: imagesPerCollectionBatch,
                        sort: mapFromSortOption(collectionSort[cid] ?? .timeDesc)
                    )
                )
            )
            
            CollectionImagePrefetcher.instance.prefetchHighQuality(
                collectionId: coll.id,
                images: coll.images
            )
            await collectionStore.updateCollection(coll, collectionImageStore)
            
            let relevantUserId = collectionToRelevantUserId[cid] ?? nil
            let items = coll.images.map { FeedImageItem(id: $0.id, collectionId: coll.id, relevantUserId: relevantUserId) }
            if items.isEmpty {
                collectionIDs.removeAll { $0 == cid }
                nextImagePage.removeValue(forKey: cid)
            } else {
                let newUniqueItems = items.filter { seenGlobalIDs.insert($0.id).inserted }
                newUniqueItems.forEach { imageToCollectionID[$0.id] = $0.collectionId }
                
                buffer.append(contentsOf: newUniqueItems)
                nextImagePage[cid]! += 1
            }
            
            if buffer.count >= size {
                break
            }
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        .init(page: page, size: size)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
