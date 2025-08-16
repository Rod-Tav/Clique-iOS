//
//  FollowersFollowingView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import SwiftUI
import AdvancedList

// for nav
enum FollowersFollowing: Hashable {
    case followers(User)
    case following(User)
}

struct FollowersFollowingView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Environment(UserStore.self) private var userStore
    
    @State private var followUserVM = FollowUserViewModel()
    @State private var followRequestsPaginationVM: FollowRequestsPaginationViewModel
    
    /// followers
    @State private var followersVM: FollowersSearchPaginationViewModel
    @FocusState private var isFollowersSearchFocused: Bool
    @State private var followersSearchText = ""
    @State private var followersListState: ListState = .loading
    @State private var followersPaginationState: AdvancedListPaginationState = .idle
    @State private var followersIsScrollAtBottom: Bool = false
    @State private var followersDebouncer = Debouncer()
    
    /// following
    @State private var followingVM: FollowingSearchPaginationViewModel
    @FocusState private var isFollowingSearchFocused: Bool
    @State private var followingSearchText = ""
    @State private var followingListState: ListState = .loading
    @State private var followingPaginationState: AdvancedListPaginationState = .idle
    @State private var followingIsScrollAtBottom: Bool = false
    @State private var followingDebouncer = Debouncer()
    
    @State private var selectedTab: Int?
    @State private var tabProgress: CGFloat = .zero
    
    private var user: User? {
        userStore.users[userId]
    }
    
    let userId: String
    
    init(uid: String, selectedTab: Int = 0, userStore: UserStore) {
        self.userId = uid
        self._selectedTab = State(initialValue: selectedTab)
        self.followersVM = .init(uid: uid, userStore: userStore)
        self.followingVM = .init(uid: uid, userStore: userStore)
        self.followRequestsPaginationVM = .init(userStore)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            
            Tabs()
            
            FollowersFollowing()
        }
        .frameTop()
        .primaryBackground()
        .padding(.bottom, 4) // 4 aligns it with tab bar for some reason
    }
}
    
// MARK: - Top Bar
extension FollowersFollowingView {
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage("arrow-left", color: .theme.iconPrimary, size: 24)
                }
            },
            header: {
                Text("People")
                    .font(.callout)
                    .fontWeight(.semibold)
            },
            trailingIcon: {
                Spacer().frame(24)
            }
        )
        .padding(16)
    }
}

// MARK: - Tabs
extension FollowersFollowingView {
    @ViewBuilder private func Tabs() -> some View {
        if let user {
            TabsWithIndicatorBar(
                tabCount: 2,
                alignment: .bottom,
                tabProgress: $tabProgress
            ) {
                Group {
                    TextTab(
                        "FOLLOWERS (\(formatNumber(user.numFollowers)))",
                        isSelected: selectedTab == 0,
                        selectedColor: Color.theme.iconPrimary,
                        unselectedColor: Color.theme.iconSecondary
                    ) {
                        selectedTab = 0
                    }
                    
                    TextTab(
                        "FOLLOWING (\(formatNumber(user.numFollowing)))",
                        isSelected: selectedTab == 1,
                        selectedColor: Color.theme.iconPrimary,
                        unselectedColor: Color.theme.iconSecondary
                    ) {
                        selectedTab = 1
                    }
                }
            }
        }
    }
    
    // MARK: - Tab View
    @ViewBuilder private func FollowersFollowing() -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                Followers()
                    .containerRelativeFrame(.horizontal)
                    .id(0)
                
                Following()
                    .containerRelativeFrame(.horizontal)
                    .id(1)
            }
            .scrollTargetLayout()
            .offsetX { value in
                tabProgress = -value / (UIScreen.width * 2)
            }
        }
//        .maxHeight()
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selectedTab)
        .scrollClipDisabled()
        .bottomTabBarPadding()
    }
}

// MARK: - Followers Pagination
extension FollowersFollowingView {
    @ViewBuilder private func Followers() -> some View {
        ScrollView {
            VStack(spacing: 16) {
                SearchBar(searchText: $followersSearchText, isSearchFocused: $isFollowersSearchFocused)
                
                if let user, userStore.currentUserId == user.id, !(followRequestsPaginationVM.items.isEmpty && followRequestsPaginationVM.page > 0) {
                    
                    FollowRequestsListView()
                        .environment(followRequestsPaginationVM)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    TextDivider("Followers")
                }
                
                AdvancedList(followersVM.items, listView: { users in
                    FollowersList(users: users)
                }, content: { userID in
                    if let user = userStore.users[userID] {
                        NavigationLink(value: user) {
                            UserCellWithFollow(uid: user.id)
    //                            .environment(followUserVM)
                        }
                    }
                }, listState: followersListState, emptyStateView: {
                    SearchUsersEmptyStateView(/*show: followingSearchText.count >= 3*/)
                }, errorStateView: { _ in
                    SearchUsersErrorStateView(listState: $followersListState, refresh: { await updateFollowers(.refresh) })
                }, loadingStateView: {
                    SearchUsersLoadingStateView()
                })
                .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateFollowers(.loadNextPage) } }) { })
                .frameTop()
                .onAppear {
                    Task {
                        guard followersVM.items.isEmpty else { return }
                        searchFollowers()
                    }
                }
                .onChange(of: followersSearchText) {
                    searchFollowers()
                }
            }
        }
        .padding(.top, 16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
    
    @ViewBuilder private func FollowersList(users: AdvancedList.Rows) -> some View {
        LazyVStack(spacing: 16, content: users)
            .padding(.bottom, 8)
    }
}

// MARK: - Following Pagination
extension FollowersFollowingView {
    @ViewBuilder private func Following() -> some View {
        VStack(spacing: 16) {
            SearchBar(searchText: $followingSearchText, isSearchFocused: $isFollowingSearchFocused)
            
            AdvancedList(followingVM.items, listView: { users in
                FollowingList(users: users)
            }, content: { userID in
                if let user = userStore.users[userID] {
                    NavigationLink(value: user) {
                        UserCellWithFollow(uid: user.id)
//                            .environment(followUserVM)
                    }
                }
            }, listState: followingListState, emptyStateView: {
                SearchUsersEmptyStateView(/*show: followingSearchText.count >= 3*/)
            }, errorStateView: { _ in
                SearchUsersErrorStateView(listState: $followingListState, refresh: { await updateFollowing(.refresh) })
            }, loadingStateView: {
                SearchUsersLoadingStateView()
            })
            .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateFollowing(.loadNextPage) } }) { })
            .frameTop()
            .onAppear {
                Task {
                    guard followingVM.items.isEmpty else { return }
                    searchFollowing()
                }
            }
            .onChange(of: followingSearchText) {
                searchFollowing()
            }
        }
        .padding([.top, .horizontal], 16)
    }
    
    @ViewBuilder private func FollowingList(users: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: users)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Helper functions
extension FollowersFollowingView {
    // MARK: - Followers
    private func updateFollowers(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: followersVM,
            listState: $followersListState,
            paginationState: $followersPaginationState,
            isScrollAtBottom: $followersIsScrollAtBottom
        )
    }
    
    private func searchFollowers() {
        @Bindable var bindableVM = followersVM
        
        SearchHelper.searchUsers(
            searchText: followersSearchText,
            query: $bindableVM.query,
            listState: $followersListState,
            debouncer: followersDebouncer,
            updateUsers: updateFollowers
        )
    }
    
    // MARK: - Following
    private func updateFollowing(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: followingVM,
            listState: $followingListState,
            paginationState: $followingPaginationState,
            isScrollAtBottom: $followingIsScrollAtBottom
        )
    }
    
    private func searchFollowing() {
        @Bindable var bindableVM = followingVM
        
        SearchHelper.searchUsers(
            searchText: followingSearchText,
            query: $bindableVM.query,
            listState: $followingListState,
            debouncer: followingDebouncer,
            updateUsers: updateFollowing
        )
    }
}

//#Preview {
//    FollowersFollowingView(user: User.MOCK_USERS[0])
//}
