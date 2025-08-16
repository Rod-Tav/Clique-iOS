////
////  CollectionFeedCellViewModel.swift
////  Clique
////
////  Created by Rod Tavangar on 12/11/24.
////
//
//import Foundation
//
//@Observable final class CollectionFeedCellViewModel {
//    
//    @MainActor func fetchCollectionCellMembers(for collection: ClCollection) -> [User] {
//        return Array(UserService.fetchCollectionCellUsers(id: collection.id))
//    }
//    
//    func fetchClique() async throws {
//        guard self.collection.clique == nil else { return }
//        
//        self.collection.clique = try await CliqueService.getCliqueById(id: collection.cliqueId)
//    }
//}
