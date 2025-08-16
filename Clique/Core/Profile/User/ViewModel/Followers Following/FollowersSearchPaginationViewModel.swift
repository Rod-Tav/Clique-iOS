//
//  FollowersSearchPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import Foundation

@Observable class FollowersSearchPaginationViewModel: PaginationViewModel {
    typealias Item = String
    typealias Input = SearchPaginationFetchInput
    
    var items: [String] = []
    var query: String = ""
    
    var page: Int = 0
    var size: Int { 20 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (SearchPaginationFetchInput) async throws -> [String]
    
    private var uid: String
    
    init(uid: String, userStore: UserStore) {
        self.uid = uid
        self.fetchFunction = { input in
            let users = try await UserService.searchUserFollowers(.init(path: .init(userId: uid), query: .init(search: input.query, page: input.page, size: input.size)))
            
            await userStore.updateUsers(users)
            
            return users.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> SearchPaginationFetchInput {
        return SearchPaginationFetchInput(query: query, page: page, size: size)
    }
}

extension FollowersSearchPaginationViewModel {
    func reset() {
        items = []
        page = 0
        done = false
    }
}
