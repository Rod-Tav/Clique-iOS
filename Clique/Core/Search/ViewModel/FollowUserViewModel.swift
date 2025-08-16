//
//  FollowUserViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/6/25.
//

import Foundation

final class FollowUserViewModel {
    static func unfollow(_ uid: String, _ userStore: UserStore) async throws {
        await MainActor.run {
            userStore.users[uid]?.relationship = .unrelated
            userStore.users[uid]?.numFollowers -= 1
            userStore.users[userStore.currentUserId!]?.numFollowing -= 1
        }
        try await UserService.unfollowUser(.init(body: .json(.init(followee: uid))))
    }
    
    static func unrequest(_ uid: String, _ userStore: UserStore) async throws {
        await MainActor.run {
            userStore.users[uid]?.relationship = .unrelated
        }
        try await UserService.unfollowUser(.init(body: .json(.init(followee: uid))))
    }
    
    static func follow(_ uid: String, isPrivate: Bool, _ userStore: UserStore) async throws {
        await MainActor.run {
            if isPrivate {
                userStore.users[uid]?.relationship = .requested
            } else {
                userStore.users[uid]?.relationship = .following
                userStore.users[uid]?.numFollowers += 1
                userStore.users[userStore.currentUserId!]?.numFollowing += 1
            }
        }
        
        try await UserService.followUser(.init(body: .json(.init(followee: uid))))
    }
}
