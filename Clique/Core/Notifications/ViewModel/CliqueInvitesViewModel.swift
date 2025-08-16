//
//  CliqueInvitesViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/4/25.
//

import Foundation

@Observable final class CliqueInvitesViewModel: PaginationViewModel {
    typealias Item = CliqueInvite
    typealias Input = EmptyPaginationFetchInput
    
    var items: [CliqueInvite] = []
    
    var page: Int = 0
    var size: Int { 5 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [CliqueInvite]
    
    init(_ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.fetchFunction = { input in
            let invites = try await CliqueService.getCliqueInvites(.init(query: .init(page: input.page, size: input.size)))
            
            let mappedInvites = invites.map { mapToCliqueInvite($0) }
            
            for invite in mappedInvites {
                await userStore.updateUser(invite.fromUser)
                await cliqueStore.updateClique(invite.clique)
            }
            
            return mappedInvites
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        return EmptyPaginationFetchInput(page: page, size: size)
    }
}
