//
//  FollowRequestCell.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import SwiftUI
import AdvancedList
import Toasts

struct FollowRequestsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(FollowRequestsPaginationViewModel.self) private var followRequestsVM
    
    @State private var viewModel = FollowRequestsViewModel()
    @State private var followVM = FollowUserViewModel()
    
    var inSheet: Bool = false
    
    private var followListState: ListState {
        followRequestsVM.followListState
    }
    
    private var followPaginationState: AdvancedListPaginationState {
        followRequestsVM.followPaginationState
    }
    
    var body: some View {
        AdvancedList(followRequestsVM.items, listView: { followRequests in
            FollowRequestsList(followRequests)
        }, content: { followRequest in
            FollowRequestCell(followRequest)
        }, listState: followListState, emptyStateView: {
            EmptyView()
        }, errorStateView: { _ in
            SomethingWentWrong {
                followRequestsVM.followListState = .loading
                await updateFollowRequests(.refresh)
            }
        }, loadingStateView: {
            CliqueProgressView()
                .infiniteFrame()
        })
        .onAppear {
            Task {
                guard followListState == .loading else { return }
                await updateFollowRequests(.loadFirstPage)
            }
        }
        .onChange(of: viewModel.triggerPresentToast) {
            presentToast(Toasts.somethingWentWrong)
        }
        .onChange(of: followRequestsVM.triggerRefresh) {
            guard followRequestsVM.followPaginationState == .idle else { return }
            
            Task {
                await updateFollowRequests(.refresh)
            }
        }
    }
    
    @ViewBuilder private func FollowRequestsList(_ followRequests: AdvancedList.Rows) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                TextDivider("Follow Requests")
                
                LazyVStack(spacing: 16, content: followRequests)
            }
            
            if !followRequestsVM.done {
                TextButton("See More") {
                    Task { await updateFollowRequests(.loadNextPage) }
                }
            }
        }
    }
    
    @ViewBuilder private func FollowRequestCell(_ fr: FollowRequest) -> some View {
        Button {
            if inSheet {
                dismiss()
            }
            tabViewCoordinator.navigate(to: fr.fromUser)
        } label: {
            HStack(spacing: 8) {
                UserPfpAsyncView(pfp: fr.fromUser.profilePic, size: UserListCellViewType.large.size, quality: .low, context: .list)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(fr.fromUser.fullname)
                        .textPrimary()
                        .font(.footnote.bold())
                    
                    Text("@\(fr.fromUser.username)")
                        .textSecondary()
                        .font(.caption2.bold())
                    
                    // TODO: PUT MUTUAL FOLLOWS HERE
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    AcceptFollowButton(fr)
                    
                    Menu {
                        Button {
                            Task {
                                await viewModel.declineFollowRequest(fr, followRequestsVM)
                            }
                        } label: {
                            Text("Decline")
                        }
                        
                        BlockButton {
                            Task {
                                do {
                                    try await UserService.blockUser(.init(path: .init(userId: fr.fromUser.id)))
                                } catch {
                                    presentToast(Toasts.somethingWentWrong)
                                }
                            }
                        }
                    } label: {
                        TinyButton()
                    }
                }
            }
            .contentShape(.rect)
        }.buttonStyle(.noHighlight)
    }
    
    // MARK: - Accept and Follow Button
    @ViewBuilder private func AcceptFollowButton(_ fr: FollowRequest) -> some View {
        if viewModel.acceptedFollowRequestIds.contains(fr.id),
           let relationship = userStore.users[fr.fromUser.id]?.relationship {
            UserFollowButton(relationship: relationship) {
                let oldUser = fr.fromUser
                
                Task {
                    do {
                        switch relationship {
                        case .following:
                            try await FollowUserViewModel.unfollow(fr.fromUser.id, userStore)
                        case .requested:
                            try await FollowUserViewModel.unrequest(fr.fromUser.id, userStore)
                        case .unrelated:
                            try await FollowUserViewModel.follow(fr.fromUser.id, isPrivate: fr.fromUser.isPrivate, userStore)
                        }
                    } catch {
                        userStore.users[fr.fromUser.id] = oldUser
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
            
            
//            switch relationship {
//            case .following, .requested:
//                UserFollowButton(relationship: relationship) {
//                    followVM.unfollow(fr.fromUser.id, userStore)
//                }
//            case .unrelated:
//                UserFollowButton(relationship: relationship) {
//                    followVM.follow(fr.fromUser.id, isPrivate: fr.fromUser.isPrivate, userStore)
//                }
//            }
        } else {
            if let loading = viewModel.acceptButtonLoadings[fr.fromUser.id], loading == true {
                CliqueProgressView()
            } else {
                SmallCTA(type: .primary, text: "Accept") {
                    haptics(.light)
                    viewModel.acceptFollowRequest(fr, userStore)
                    AppService.decrementAppBadge()
                }
            }
        }
    }
    
    // MARK: - Pagination funciton
    private func updateFollowRequests(_ operation: PaginationOperationType) async {
        @Bindable var bindableVM = followRequestsVM
        
        await PaginationHelper.updateItems(
            operation,
            viewModel: followRequestsVM,
            listState: $bindableVM.followListState,
            paginationState: $bindableVM.followPaginationState
        )
    }
}
