//
//  UserSearchPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 12/7/24.
//

import Foundation

@Observable class UserSearchPaginationViewModel: PaginationViewModel {
    typealias Item = String
    typealias Input = SearchPaginationFetchInput
    
    var items: [String] = []
    var query: String = ""
    
    var page: Int = 0
    var size: Int { 15 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (SearchPaginationFetchInput) async throws -> [String]
    
    init(_ userStore: UserStore) {
        self.fetchFunction = { input in
            let users = try await UserService.searchUsers(.init(query: .init(search: input.query, page: input.page, size: input.size)))
            
            await userStore.updateUsers(users)
            
            return users.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> SearchPaginationFetchInput {
        return SearchPaginationFetchInput(query: query, page: page, size: size)
    }
}

extension UserSearchPaginationViewModel {
    func reset() {
        items = []
        page = 0
        done = false
    }
}
