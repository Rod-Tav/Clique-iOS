//
//  LikedUsersListView.swift
//  Clique
//
//  Created by Rod Tavangar on 4/29/25.
//

import SwiftUI
import AdvancedList
import Toasts

struct LikedUsersListView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State var viewModel: LikedUsersPaginationViewModel
    @State private var followUserViewModel = FollowUserViewModel()
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    let imageId: String
    var fromCollectionDetail: Bool = false
    
    init(imageId: String, fromCollectionDetail: Bool = false, _ userStore: UserStore) {
        self.imageId = imageId
        self.fromCollectionDetail = fromCollectionDetail
        self.viewModel = .init(imageId: imageId, userStore)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TopBar()
            
            AdvancedList(viewModel.items, listView: { users in
                MemberList(users)
            }, content: { userID in
                if let user = userStore.users[userID] {
                    MemberCell(user)
                }
            }, listState: listState, emptyStateView: {
                EmptyStateView()
            }, errorStateView: { _ in
                ErrorStateView()
            }, loadingStateView: {
                LoadingStateView()
            })
            .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateMembers(.loadNextPage) } }) { })
            .task {
                guard listState == .loading else { return }
                await updateMembers(.loadFirstPage)
            }
//            .environment(followUserViewModel)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Top Bar
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {},
            header: {
                Text("Likes")
                    .textPrimary()
                    .font(.callout.bold())
            },
            trailingIcon: {}
        )
    }
    
    // MARK: - Member list
    @ViewBuilder private func MemberList(_ users: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: users)
        }
        .scrollBarIgnorePadding(16)
    }
    
    // MARK: - Member cell
    @ViewBuilder private func MemberCell(_ user: User) -> some View {
        Button {
            navigate(to: user)
        } label: {
            UserCellWithFollow(uid: user.id)
        }
    }
    
    // TODO: DRY
    private func navigate(to user: User) {
//        dismiss()
//        if fromCollectionDetail {
//            tabViewCoordinator.pan = .disabled // TODO: weird ass behavior
//            appCoordinator.lookingAtUserProfileFromCollectionDetail = true
//            tabViewCoordinator.showTabBar = true
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            tabViewCoordinator.navigate(to: user)
//        }
        
        if !fromCollectionDetail {
            dismiss()
            tabViewCoordinator.navigate(to: user)
        }
    }
}

// MARK: - Pagination state views
extension LikedUsersListView {
    // this should never happen
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateMembers(.refresh)
        }
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateMembers(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
