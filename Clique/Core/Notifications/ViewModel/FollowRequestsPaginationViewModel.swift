//
//  FollowRequestsPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/4/25.
//

import Foundation
import AdvancedList

@Observable final class FollowRequestsPaginationViewModel: PaginationViewModel {
    typealias Item = FollowRequest
    typealias Input = EmptyPaginationFetchInput
    
    var items: [FollowRequest] = []
    
    var page: Int = 0
    var size: Int { 5 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [FollowRequest]
    
    var followListState: ListState = .loading
    var followPaginationState: AdvancedListPaginationState = .idle
    var triggerRefresh: Bool = false
    
    init(_ userStore: UserStore) {
        self.fetchFunction = { input in
            let frs = try await UserService.getFollowRequests(.init(query: .init(page: input.page, size: input.size)))
            
            for user in frs.map({ $0.fromUser }) {
                await userStore.updateUser(user)
            }
            
            return frs
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        return EmptyPaginationFetchInput(page: page, size: size)
    }
}

