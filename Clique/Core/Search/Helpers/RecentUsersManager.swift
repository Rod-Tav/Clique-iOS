//
//  RecentUsersManager.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import SwiftUI

class RecentUsersManager: ObservableObject {
    private let storageKey = "recentUsers"
    
    @AppStorage("recentUsers") static var storedUsersData: Data = Data()
    
    @Published var recentUsers: [User] = []
    
    init(_ userStore: UserStore) {
        loadRecentUsers(userStore)
    }
    
    private func loadRecentUsers(_ userStore: UserStore) {
        guard !RecentUsersManager.storedUsersData.isEmpty else { return }
        
        if let decodedUsers = try? JSONDecoder().decode([User].self, from: RecentUsersManager.storedUsersData) {
            recentUsers = decodedUsers
//            for index in recentUsers.indices {
//                Task {
//                    let relationship = try await UserService.getFollowStatus(input: .init(path: .init(userId: recentUsers[index].id)))
//                    await MainActor.run {
//                        self.recentUsers[index].relationship = relationship
//                    }
//                }
//            }
//            Task {
//                await userStore.updateUsers(recentUsers)
//            }
            
            for user in recentUsers {
                Task {
                    let newUser = try await UserService.getUserById(user.id)
                    
                    await userStore.updateUser(newUser)
                }
            }
        }
    }
    
    func addRecentUser(_ user: User) {
        // Remove user if it already exists to avoid duplicates
        recentUsers.removeAll { $0.id == user.id }
        
        // Insert at the beginning
        recentUsers.insert(user, at: 0)
        
        // Keep only the last 10 users
        if recentUsers.count > 10 {
            recentUsers.removeLast()
        }
        
        saveRecentUsers()
    }
    
    func removeRecentUser(_ user: User) {
        recentUsers.removeAll(where: { $0.id == user.id })
        
        saveRecentUsers()
    }
    
    private func saveRecentUsers() {
        if let encodedData = try? JSONEncoder().encode(recentUsers) {
            RecentUsersManager.storedUsersData = encodedData
        }
    }
}
