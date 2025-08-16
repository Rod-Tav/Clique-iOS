//
//  UserProfileViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/17/24.
//

import Foundation

@Observable final class UserProfileViewModel {
//    var user: User
//    var followStatus: UserRelationship? = nil
//    var triggerPresentToast: Bool = false
    var triggerRefresh: Bool = false
    var triggerUserCliquesRefresh: Bool = false
    var isRefreshing: Bool = false
    
//    init(user: User) {
//        self.user = user
//    }
    
    func getFollowStatus(uid: String) async throws -> UserRelationship {
        return try await UserService.getFollowStatus(input: .init(path: .init(userId: uid)))
    }
    
    func follow(_ uid: String) async throws {
//        Task {
//            do {
//                if user.isPrivate {
//                    user.relationship = .requested
//                } else {
//                    user.relationship = .following
//                    user.numFollowers += 1
//                }
                try await UserService.followUser(.init(body: .json(.init(followee: uid))))
//            } catch {
//                user.relationship = .unrelated
//                if !user.isPrivate {
//                    user.numFollowers -= 1
//                }
//                triggerPresentToast.toggle()
//            }
//        }
    }
    
    func unfollow(_ uid: String) async throws {
//        let oldFollowStatus = user.relationship // could be requested
//        Task {
//            do {
//                user.relationship = .unrelated
//                userStore.usersById[user.id]?.numFollowing -= 1
//                user.numFollowers -= 1
                try await UserService.unfollowUser(.init(body: .json(.init(followee: uid))))
//            } catch {
//                user.relationship = oldFollowStatus
//                user.numFollowers += 1
//                UserService.shared.currentUser?.numFollowing += 1
//                userStore.usersById[user.id]?.numFollowing += 1
//                triggerPresentToast.toggle()
//            }
//        }
    }
}
