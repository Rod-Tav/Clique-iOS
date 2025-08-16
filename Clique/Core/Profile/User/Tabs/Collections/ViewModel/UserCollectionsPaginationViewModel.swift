//
//  UserCollectionsViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/21/24.
//

import Foundation

@Observable final class UserCollectionsPaginationViewModel: PaginationViewModel {
    typealias Item = String // collection id
    typealias Input = UserPaginationFetchInput
    
    var items: [String] = []
    private var uid: String
    
    var page: Int = 0
    var size: Int { 10 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (UserPaginationFetchInput) async throws -> [String]
    
    init(uid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.uid = uid
        self.fetchFunction = { input in
            let collections = try await CollectionService.getCollectionsByUser(.init(path: .init(userId: uid), query: .init(page: input.page, size: input.size)))
            
            await collectionStore.updateCollections(collections, collectionImageStore)
            
            return collections.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> UserPaginationFetchInput {
        return UserPaginationFetchInput(uid: uid, page: page, size: size)
    }
}
