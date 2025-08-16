//
//  CollectionViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/23/24.
//

import Foundation

@Observable final class CollectionViewModel {
    func fetchClique(cid: String, _ cliqueStore: CliqueStore) async throws {
        guard await cliqueStore.cliques[cid] == nil else { return }
        
        let collectionClique = try await CliqueService.getCliqueById(id: cid)
        
        await cliqueStore.updateClique(collectionClique)
    }
}
