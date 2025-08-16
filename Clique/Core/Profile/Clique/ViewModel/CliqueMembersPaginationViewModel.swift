//
//  CliqueMembersPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import Foundation

@Observable class CliqueMembersPaginationViewModel: PaginationViewModel {
    typealias Item = String // user id
    typealias Input = CliquePaginationFetchInput
    
    var items: [String] = []
    
    var page: Int = 0
    var size: Int { 15 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CliquePaginationFetchInput) async throws -> [String]
    
    private var cid: String
    
    init(cid: String, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.cid = cid
        
        self.fetchFunction = { input in
            let users = try await CliqueService.getCliqueMembers(.init(path: .init(cliqueId: input.cid), query: .init(page: input.page, size: input.size)))
            
            if input.page == 0 {
                await MainActor.run {
                    cliqueStore.cliques[cid]?.leader = users[0].id
                }
            }
            
            await MainActor.run {
                cliqueStore.cliques[cid]?.memberIDs?.formUnion(users.map { $0.id }) ?? (cliqueStore.cliques[cid]?.memberIDs = Set(users.map { $0.id }))
            }
            
            await userStore.updateUsers(users)
            
            return users.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> CliquePaginationFetchInput {
        return CliquePaginationFetchInput(cid: cid, page: page, size: size)
    }
}
