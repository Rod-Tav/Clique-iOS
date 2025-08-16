//
//  FollowRequestsViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import Foundation

@Observable final class FollowRequestsViewModel {
//    var relationships = [String: UserRelationship]() // user id
    var acceptButtonLoadings = [String: Bool]()  // user id
    var acceptedFollowRequestIds = [String]() // fr ids
    
    var triggerPresentToast: Bool = false
    
    func acceptFollowRequest(_ fr: FollowRequest, _ userStore: UserStore) {
        Task { @MainActor in
            do {
                acceptButtonLoadings[fr.fromUser.id] = true
                
                if userStore.users[fr.fromUser.id]?.relationship != nil {
                    try await UserService.acceptFollowRequest(.init(path: .init(followRequestId: fr.id)))
                    
                    userStore.users[userStore.currentUserId!]?.numFollowers += 1
                    
//                    relationships[fr.fromUser.id] = relationship
                } else {
                    print("rel is nil")
                    // TODO: Run both tasks in parallel
                    try await UserService.acceptFollowRequest(.init(path: .init(followRequestId: fr.id)))
                    
                    let relationship = try await UserService.getFollowStatus(input: .init(path: .init(userId: fr.fromUser.id)))
                    
                    userStore.users[fr.fromUser.id]?.relationship = relationship
                    userStore.users[userStore.currentUserId!]?.numFollowers += 1
//                    relationships[fr.fromUser.id] = try await followStatus
                }
                
                acceptedFollowRequestIds.append(fr.id)
                acceptButtonLoadings[fr.id] = false
            } catch {
                acceptButtonLoadings[fr.id] = false
                triggerPresentToast.toggle()
            }
        }
    }
    
//    func unfollow(_ uid: String, _ userStore: UserStore) {
//        Task {
//            do {
//                userStore.users[uid]?.relationship = .unrelated
////                relationships[uid] = UserRelationship.unrelated
//                try await UserService.unfollowUser(.init(body: .json(.init(followee: uid))))
//            } catch {
//                userStore.users[uid]?.relationship = .following
////                relationships[uid] = .following
//                triggerPresentToast.toggle()
//            }
//        }
//    }
//    
//    func follow(_ uid: String, _ userStore: UserStore) {
//        Task {
//            do {
//                userStore.users[uid]?.relationship = .following
////                relationships[uid] = .following
//                try await UserService.followUser(.init(body: .json(.init(followee: uid))))
//            } catch {
//                userStore.users[uid]?.relationship = .unrelated
////                relationships[uid] = UserRelationship.unrelated
//                triggerPresentToast.toggle()
//            }
//        }
//    }
}
