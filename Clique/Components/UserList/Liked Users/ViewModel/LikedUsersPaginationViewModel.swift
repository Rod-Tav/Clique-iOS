//
//  LikedUsersPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 4/29/25.
//

import Foundation

@Observable final class LikedUsersPaginationViewModel: PaginationViewModel {
    typealias Item = String // user id
    typealias Input = CollectionItemPaginationFetchInput
    
    var items: [String] = []
    
    var page: Int = 0
    var size: Int = 15
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CollectionItemPaginationFetchInput) async throws -> [String]
    
    private var imageId: String
    
    init(imageId: String, _ userStore: UserStore) {
        self.imageId = imageId
        self.fetchFunction = { input in
            let users = try await CollectionService.getLiked(.init(path: .init(collectionItemId: input.imageId), query: .init(page: input.page, size: input.size)))
            
            await userStore.updateUsers(users)
            
            return users.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> CollectionItemPaginationFetchInput {
        return CollectionItemPaginationFetchInput(imageId: imageId, page: page, size: size)
    }
}
