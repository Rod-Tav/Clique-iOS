//
//  CollectionItemsPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/16/25.
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case timeAsc, timeDesc, likesDesc, likesAsc
    
    var id: Self { self }

    var title: String {
        switch self {
        case .timeAsc: return "Oldest to newest"
        case .timeDesc: return "Newest to oldest"
        case .likesAsc: return "Least likes"
        case .likesDesc: return "Most likes"
        }
    }
    
    var systemImage: String {
        switch self {
        case .timeAsc:
            "clock.arrow.circlepath"
        case .timeDesc:
            "clock.arrow.2.circlepath"
        case .likesDesc:
            "arrow.up.heart.fill"
        case .likesAsc:
            "arrow.down.heart.fill"
        }
    }
}

@Observable final class CollectionImagesPaginationViewModel: PaginationViewModel {
    typealias Item = String // collection image id
    typealias Input = CollectionItemsPaginationFetchInput
    
    var items: [String] = []
    
    var page: Int = 0
    var size: Int { 25 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CollectionItemsPaginationFetchInput) async throws -> [String]
    
    private var collectionDataId: String
    var sortOption: SortOption
    var isDetailView: Bool = false // Track if used in detail view context
    
    init(collectionDataId: String, sortOption: SortOption, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.collectionDataId = collectionDataId
        self.sortOption = sortOption
        self.fetchFunction = { input in
            var collection = try await CollectionService.getCollectionById(.init(path: .init(collectionDataId: input.collectionDataId), query: .init(page: input.page, size: input.size, sort: mapFromSortOption(self.sortOption))))
            
            if sortOption == .likesDesc {
                collection.mostLikedImage = collection.images.first?.id
            }
            
            let collectionImages = collection.images
            
            // Prefetch based on context - detail view needs high quality, grid needs low quality
            let context: CollectionImagePrefetcher.PrefetchContext = self.isDetailView ? .detailView : .gridView
            CollectionImagePrefetcher.instance.prefetchForContext(
                context,
                collectionId: collection.id,
                images: collection.images
            )
            
            await collectionStore.updateCollection(collection, collectionImageStore)
            
            return collectionImages.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> CollectionItemsPaginationFetchInput {
        return CollectionItemsPaginationFetchInput(collectionDataId: collectionDataId, page: page, size: size)
    }
}
