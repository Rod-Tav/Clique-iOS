//
//  SearchView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/10/24.
//

import SwiftUI
import AdvancedList
import Toasts

struct SearchView: View {
//    @Environment(NetworkMonitor.self) private var networkMonitor
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @StateObject private var recentUsersManager: RecentUsersManager
    
    @State private var userViewModel: UserSearchPaginationViewModel
    @State private var searchViewModel = FollowUserViewModel()
    
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var hasSearchResults: Bool = false
    
    @State private var searchCliques = false
    @State private var selectedTab: Int = 0
    
    @State private var listState: ListState = .items
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
//    @State var membersPgVM: CliqueMembersPaginationViewModel
    
    @State private var membersListState: ListState = .loading
    @State private var membersPaginationState: AdvancedListPaginationState = .idle
    @State private var membersIsScrollAtBottom: Bool = false
    
    @State private var showAddFriendsSheet: Bool = false
    
    @State private var debouncer = Debouncer()
    
    init(/*cid: String, */_ userStore: UserStore/*, _ cliqueStore: CliqueStore*/) {
        self.userViewModel = .init(userStore)
        self._recentUsersManager = StateObject(wrappedValue: .init(userStore))
//        self.membersPgVM = .init(cid: cid, userStore, cliqueStore)
    }
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableVm = tabViewCoordinator
        
        TabNavigationStack(path: $bindableVm.searchNavigationPath) {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                
                VStack(spacing: 16) {
                    SearchBar(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        disableAutocorrect: true,
                        onSubmit: {
                            hasSearchResults = true
                        },
                        onCancel: {
                            hasSearchResults = false
                        }
                    )
                        .padding(.horizontal, 16)
                    
                    Users()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .onReceive(of: .focusSearchTab) { _ in
                    isSearchFocused = true
                }
                .padding(.bottom, isSearchFocused ? 0 : Constants.bottomTabBarHeight - safeAreaInsets.bottom + 16)
                .primaryBackground()
                .onDisappear {
                    searchText = ""
                    userViewModel.reset()
                    //                searchViewModel.reset()
                }
            }
        }
        .sheet(isPresented: $showAddFriendsSheet) {
            AddContactsView()
                .bottomSheetModifiers()
        }
    }
    
    // MARK: Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Spacer()
                    .frame(24)
            },
            header: {
                Text("Search")
                    .textPrimary()
                    .font(.callout.bold())
            },
            trailingIcon: {
                Button {
                    showAddFriendsSheet = true
                } label: {
                    IconImage("add-user", color: .theme.iconPrimary, size: 24)
                }.buttonStyle(.noHighlight)
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .primaryBackground()
    }
    
    // MARK: User List
    @ViewBuilder private func Users() -> some View {
        VStack(spacing: 8) {
            if (!isSearchFocused && !hasSearchResults) || searchText.isEmpty {
                VStack(spacing: 16) {
                    TextDivider("Recents")
                        
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(recentUsersManager.recentUsers) { user in
                                Button {
                                    tabViewCoordinator.navigate(to: user)
                                } label: {
                                    HStack {
                                        // TODO: have follow status on recent page update if updated elsewhere. also todo in RecentUsersManager
//                                        UserCellWithFollow(uid: user.id)
                                        
                                        UserListCellView(uid: user.id, type: .search)
                                        
                                        Spacer()
                                        
                                        Button {
                                            recentUsersManager.removeRecentUser(user)
                                        } label: {
                                            IconImage("x-icon", color: .theme.iconSecondary, size: 16)
                                        }.buttonStyle(.noHighlight)
                                    }
                                    .contentShape(.rect)
                                }.noHighlight()
                            }
                        }
                    }
                    .scrollBarIgnorePadding(16)
                }
                .padding(.horizontal, 16)
                .frameTop()
            } else {
                AdvancedList(userViewModel.items, listView: { users in
                    UserList(users: users)
                }, content: { userID in
                    if let user = userStore.users[userID] {
                        Button {
                            tabViewCoordinator.navigate(to: user)
                            recentUsersManager.addRecentUser(user)
                        } label: {
                            UserCellWithFollow(uid: user.id)
                        }.buttonStyle(.noHighlight)
                    }
                }, listState: listState, emptyStateView: {
                    SearchUsersEmptyStateView(/*show: searchText.count >= 3*/)
                }, errorStateView: { _ in
                    SearchUsersErrorStateView(listState: $listState, refresh: { await updateUsers(.refresh) })
                }, loadingStateView: {
                    SearchUsersLoadingStateView()
                })
                .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateUsers(.loadNextPage) } }) { })
                .frameTop()
            }
        }
        .infiniteFrame()
        .onChange(of: searchText) {
            if searchText.isEmpty {
                print("resetting")
                listState = .items
                paginationState = .idle
                userViewModel.reset()
                hasSearchResults = false
            } else {
                searchUsers()
            }
        }
    }
    
    private func UserList(users: AdvancedList.Rows) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                LazyVStack(spacing: 16, content: users)
                //
                //            CliqueProgressView()
                //                .opacity(paginationState == .loading && userViewModel. ? 1 : 0)
                // would need to keep this part
                //                .onBecomingVisible {
                //                    isScrollAtBottom = true
                //                }
            }
            .frameTop()
        }
    }
}

// MARK: - Helper functions
extension SearchView {
    private func updateUsers(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: userViewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
    
    private func searchUsers() {
        @Bindable var bindableVM = userViewModel
        
        SearchHelper.searchUsers(
            searchText: searchText,
            query: $bindableVM.query,
            listState: $listState,
            debouncer: debouncer,
            updateUsers: updateUsers
        )
    }
}

//#Preview {
//    SearchView(UserStore())
//        .environment(TabViewCoordinator())
////        .environment(NetworkMonitor())
//}
