//
//  UserCliquesViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 1/31/25.
//

import Foundation

@Observable final class UserCliquesPaginationViewModel: PaginationViewModel {
    typealias Item = String // clique id
    typealias Input = UserPaginationFetchInput
    
    var items: [String] = []
    
    var page: Int = 0
    var size: Int { 15 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (UserPaginationFetchInput) async throws -> [String]
    
    private var uid: String
    
    init(uid: String, _ cliqueStore: CliqueStore) {
        self.uid = uid
        self.fetchFunction = { input in
            let cliques = try await CliqueService.getUserCliques(.init(path: .init(userId: input.uid), query: .init(page: input.page, size: input.size)))
            
            await cliqueStore.updateCliques(cliques)
            
            return cliques.map({ $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> UserPaginationFetchInput {
        return UserPaginationFetchInput(uid: uid, page: page, size: size)
    }
}
