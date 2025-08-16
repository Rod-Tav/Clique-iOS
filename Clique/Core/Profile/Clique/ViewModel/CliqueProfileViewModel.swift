//
//  CliqueProfileViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/25/24.
//

import Foundation

@Observable final class CliqueProfileViewModel  {
    var firstXMembers = [User]()
//    var relation: CliqueRelationship? = nil
    
    var triggerRefresh: Bool = false
    var isRefreshing: Bool = false
    
    private var cid: String
    
    init(cid: String) {
        self.cid = cid
    }
    
    // causing weird crahses -- something to do with the stores.... made MainActor for now
    @MainActor func fetchCliqueFirstXMembers(count: Int, total: Int, _ userStore: UserStore, _ cliqueStore: CliqueStore) async throws {
        if let memberIDs = cliqueStore.cliques[cid]?.memberIDs, memberIDs.count >= total {
            firstXMembers = memberIDs.compactMap { userStore.users[$0] }
            return
        }
        
        let users = try await CliqueService.getCliqueMembers(.init(path: .init(cliqueId: cid), query: .init(page: 0, size: count)))
        let leader = users[0]
        
        await MainActor.run {
            cliqueStore.cliques[cid]?.memberIDs?.formUnion(users.map { $0.id }) ?? (cliqueStore.cliques[cid]?.memberIDs = Set(users.map { $0.id }))
        }
        
        cliqueStore.cliques[cid]?.leader = leader.id
        userStore.updateUsers(users)
        
        firstXMembers = users
    }
}
