//
//  CliqueCollectionsViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/12/24.
//

import SwiftUI

@Observable final class CliqueCollectionsPaginationViewModel: PaginationViewModel {
    typealias Item = String // collection ids
    typealias Input = CliquePaginationFetchInput
    
    var items: [String] = []
    private var cid: String
    
    var page: Int = 0
    var size: Int { 10 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CliquePaginationFetchInput) async throws -> [String]
    
    init(cid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.cid = cid
        self.fetchFunction = { input in
            let collections = try await CollectionService.getCollectionsByClique(.init(path: .init(cliqueId: input.cid), query: .init(page: input.page, size: input.size)))
            
            await collectionStore.updateCollections(collections, collectionImageStore)
            
            return collections.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> CliquePaginationFetchInput {
        return CliquePaginationFetchInput(cid: cid, page: page, size: size)
    }
}
