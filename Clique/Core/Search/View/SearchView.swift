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
    
    var body: some View {
        @Bindable var bindableVm = tabViewCoordinator
        
        TabNavigationStack(path: $bindableVm.searchNavigationPath) {
            VStack(alignment: .leading, spacing: 0) {
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
                
                VStack(spacing: 16) {
                    SearchBar(searchText: $searchText, isSearchFocused: $isSearchFocused, disableAutocorrect: true)
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
    
    @ViewBuilder private func Users() -> some View {
        VStack(spacing: 8) {
            if !isSearchFocused || searchText.isEmpty {
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
//        .onChange(of: searchViewModel.triggerPresentToast) {
//            presentToast(Toasts.somethingWentWrong)
//        }
        .onChange(of: searchText) {
            if searchText.isEmpty {
                print("resetting")
                listState = .items
                paginationState = .idle
                userViewModel.reset()
            } else {
                searchUsers()
            }
        }
    }
}

// MARK: - Users
extension SearchView {
    // for some reason can't be abstracted to struct
    @ViewBuilder private func UserList(users: AdvancedList.Rows) -> some View {
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

// MARK: - People You May Know
//extension SearchView {
//    @ViewBuilder private func PeopleYouMayKnow() -> some View {
//        TextDivider("People You May Know")
//        
//        AdvancedList(membersPgVM.items, listView: { users in
//            MemberList(users)
//        }, content: { userID in
//            if let user = userStore.users[userID] {
//                MemberCell(user)
//            }
//        }, listState: membersListState, emptyStateView: {
//            EmptyStateView()
//        }, errorStateView: { _ in
//            ErrorStateView()
//        }, loadingStateView: {
//            LoadingStateView()
//        })
//        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateMembers(.loadNextPage) } }) { })
//        .onAppear {
//            Task {
//                guard membersListState == .loading else { return }
//                await updateMembers(.loadFirstPage)
//            }
//        }
//    }
//    
//    // MARK: - Member list
//    @ViewBuilder private func MemberList(_ users: AdvancedList.Rows) -> some View {
//        LazyVStack(spacing: 16, content: users)
//    }
//    
//    // MARK: - Member cell
//    @ViewBuilder private func MemberCell(_ user: User) -> some View {
//        Button {
//            tabViewCoordinator.navigate(to: user)
//        } label: {
//            UserCellWithFollow(uid: user.id, isLeader: user.id == membersPgVM.items.first?.id)
//        }
//    }
//    
//    // this should never happen
//    @ViewBuilder private func EmptyStateView() -> some View {
//        NothingHereYetView()
//    }
//    
//    @ViewBuilder private func ErrorStateView() -> some View {
//        SomethingWentWrong {
//            listState = .loading
//            await updateMembers(.refresh)
//        }
//        .padding(.horizontal, 16)
//        .maxHeight()
//    }
//    
//    @ViewBuilder private func LoadingStateView() -> some View {
//        CliqueProgressView()
//            .infiniteFrame()
//    }
//    
//    private func updateMembers(_ operation: PaginationOperationType) async {
//        await PaginationHelper.updateItems(
//            operation,
//            viewModel: membersPgVM,
//            listState: $membersListState,
//            paginationState: $membersPaginationState,
//            isScrollAtBottom: $membersIsScrollAtBottom
//        )
//    }
//}

// MARK: - Cliques
extension SearchView {
    @ViewBuilder private func Cliques() -> some View {
        if isSearchFocused {
//            SearchCliqueListView(config: .search, searchText: searchText)
        } else {
            VStack(spacing: 8) {
                TextDivider("Recents")
                    .padding(.horizontal, 16)
                
//                SearchCliqueListView(config: .search, searchText: searchText)
            }
        }
    }
}

// MARK: - Helper functions
extension SearchView {
    private func updateUsers(_ operation: PaginationOperationType) async {
//        print("updating users", operation)
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
