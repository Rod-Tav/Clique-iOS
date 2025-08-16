////
////  UserListViewModel.swift
////  Clique
////
////  Created by Rod Tavangar on 6/16/24.
////
//
//import Foundation
//
//class UserListViewModel: ObservableObject {
//    @Published var users = [User]()
//    
//    @MainActor
//    func fetchUsers(forConfig config: UserListConfig) {
//        self.users = UserService.fetchUsers(forConfig: config)
//    }
//}
