//
//  SearchUsersViews.swift
//  Clique
//
//  Created by Rod Tavangar on 2/1/25.
//

import SwiftUI
import AdvancedList
import Toasts

struct SearchUsersEmptyStateView: View {
//    let show: Bool
    
    var body: some View {
//        if show {
            Text("No users found")
//        }
    }
}

struct SearchUsersErrorStateView: View {
    @Binding var listState: ListState
    let refresh: () async -> Void
    
    var body: some View {
        SomethingWentWrong {
            listState = .loading
            Task { await refresh() }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
}

struct SearchUsersLoadingStateView: View {
//    let users: [User]
    
    var body: some View {
//        LazyVStack(spacing: 16) {
//            ForEach(users) { user in
//                SearchUsersUserCell(user: user)
//            }
//        }
//        .frameTop()
        CliqueProgressView()
    }
}

struct UserCellWithFollow: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    
    let uid: String
    var isLeader: Bool = false
    
    private var user: User? {
        userStore.users[uid]
    }
    
    var body: some View {
        if let user {
            HStack {
                UserListCellView(uid: user.id, type: .search, isLeader: isLeader)
                
                Spacer()
                
                if user.id != userStore.currentUserId, let relationship = userStore.users[user.id]?.relationship {
                    UserFollowButton(relationship: relationship) {
                        let oldUser = user
                        let oldCurrentUser = userStore.currentUser
                        
                        Task {
                            do {
                                switch relationship {
                                case .following:
                                    try await FollowUserViewModel.unfollow(uid, userStore)
                                case .requested:
                                    try await FollowUserViewModel.unrequest(uid, userStore)
                                case .unrelated:
                                    try await FollowUserViewModel.follow(uid, isPrivate: user.isPrivate, userStore)
                                }
                            } catch {
                                userStore.users[uid] = oldUser
                                userStore.users[userStore.currentUserId!] = oldCurrentUser
                                presentToast(Toasts.somethingWentWrong)
                            }
                        }
                    }
                    
                    //                switch relationship {
                    //                case .following, .requested:
                    //                    UserFollowButton(relationship: relationship) {
                    //                        FollowUserViewModel.unfollow(uid, userStore)
                    //                    }
                    //                case .unrelated:
                    //                    UserFollowButton(relationship: relationship) {
                    //                        FollowUserViewModel.follow(uid, isPrivate: user.isPrivate, userStore)
                    //                    }
                    //                }
                }
            }
//            .onAppear {
//                Task {
//                    guard let cuid = userStore.currentUserId, user.id != cuid, userStore.users[user.id]?.relationship == nil else { return }
//                    //                    print(userStore.users[user.id]?.relationship)
//                    do {
//                        //                    var updatedUser = user
//                        let relationship = try await UserService.getFollowStatus(input: .init(path: .init(userId: uid)))
//                        userStore.users[user.id]?.relationship = relationship
//                        
//                        //                    await MainActor.run {
//                        //                        await userStore.updateUser(updatedUser)
//                        //                    }
//                        //                    try await FollowUserViewModel.fetchRelationship(uid: uid, userStore)
//                    } catch {
//                        presentToast(Toasts.somethingWentWrong)
//                    }
//                }
//            }
            .contentShape(.rect)
            //        .padding(.horizontal, 16)
            .maxWidth(.leading)
        }
    }
}
