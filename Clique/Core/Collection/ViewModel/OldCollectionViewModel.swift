////
////  OldCollectionViewModel.swift
////  Clique
////
////  Created by Rod Tavangar on 12/4/24.
////
//
//import Foundation
//
//class OldCollectionViewModel: ObservableObject {
//    @Published var collection: ClCollection
//    // these values get replaced with view heights
//    @Published var minHeight: CGFloat = 111
//    @Published var maxHeight: CGFloat = 425
//    
//    init(collection: ClCollection) {
//        self.collection = collection
//    }
//    
//    func fetchClique() -> Clique {
//        return CliqueService.fetchClique(id: collection.clique.id)
//    }
//    
//    @MainActor
//    func fetchCliqueMembers(cid: String) -> [User] {
//        // TODO: check this isn't being spammed
//        return Array(UserService.fetchUsers(forConfig: .members(cliqueID: cid)).prefix(15)) // TODO: make specific to only get first 5
//        // TODO: make fetching memberCount separate from first 5 to pass into CliqueMembersView
//    }
//}
