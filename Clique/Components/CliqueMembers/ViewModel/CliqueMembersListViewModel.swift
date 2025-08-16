////
////  CliqueMembersListViewModel.swift
////  Clique
////
////  Created by Rod Tavangar on 12/12/24.
////
//
//import Foundation
//
//@Observable
//final class CliqueMembersListViewModel {
//    var members = [User]()
//    
//    // leader must be first
//    @MainActor
//    func fetchMembers(cid: String) {
//        self.members = UserService.fetchUsers(forConfig: .members(cliqueID: cid))
//    }
//}
