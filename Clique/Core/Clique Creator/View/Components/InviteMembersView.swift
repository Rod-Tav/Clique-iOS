//
//  InviteMembersView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/5/25.
//

import SwiftUI
import AdvancedList

struct InviteMembersView: View {
    @Environment(UserStore.self) private var userStore
    
    @State private var userSearchViewModel: UserSearchPaginationViewModel
    
    @State private var listState: ListState = .items
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    @Binding var invitedMembers: [User]
    @State private var debouncer = Debouncer()
    
    init(userStore: UserStore, searchText: Binding<String>, isSearchFocused: FocusState<Bool>.Binding, invitedMembers: Binding<[User]>) {
        self.userSearchViewModel = .init(userStore)
        self._searchText = searchText
        self._isSearchFocused = isSearchFocused
        self._invitedMembers = invitedMembers
    }
    
    var body: some View {
        VStack(spacing: 24) {
            SearchBar(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                buttonText: invitedMembers.isEmpty ? "Cancel" : "Done",
                disableAutocorrect: true
            )
            
            if !isSearchFocused, searchText.isEmpty {
                InvitedAndSuggested()
            } else {
                AdvancedList(userSearchViewModel.items, listView: { users in
                    UserList(users: users)
                }, content: { userID in
                    if let user = userStore.users[userID] {
                        UserCell(user: user)
                    }
                }, listState: listState, emptyStateView: {
                    //                    SearchUsersEmptyStateView(/*show: searchText.count >= 3*/)
                    if searchText.isEmpty {
                        InvitedAndSuggested()
                    } else {
                        SearchUsersEmptyStateView()
                    }
                }, errorStateView: { _ in
                    SearchUsersErrorStateView(listState: $listState, refresh: { await updateUsers(.refresh) })
                }, loadingStateView: {
                    SearchUsersLoadingStateView()
                })
                .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateUsers(.loadNextPage) } }) { })
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchText) {
            if searchText.isEmpty {
                //                print("resetting")
                listState = .items
                paginationState = .idle
                userSearchViewModel.reset()
            } else {
                searchUsers()
            }
        }
    }
}

// MARK: - Search
extension InviteMembersView {
    @ViewBuilder private func UserList(users: AdvancedList.Rows) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                LazyVStack(spacing: 16, content: users)
                
                //            CliqueProgressView()
                //                .opacity(paginationState == .loading ? 1 : 0)
                // would need to keep this part
                //                .onBecomingVisible {
                //                    isScrollAtBottom = true
                //                }
            }
            .frameTop()
        }
        .scrollBarIgnorePadding(16)
        .scrollDisabled(isSearchFocused)
        .simultaneousGesture(DragGesture().onChanged { _ in
            guard isSearchFocused else { return }
            isSearchFocused = false
        })
    }
    
    @ViewBuilder private func UserCell(user: User) -> some View {
        if userStore.currentUserId != user.id {
            HStack(spacing: 0) {
                UserListCellView(uid: user.id, type: .large)
                
                Spacer()
                
                SmallCTA(
                    type: invitedMembers.contains(where: { $0.id == user.id }) ? .secondary : .primary,
                    leadingIcon: invitedMembers.contains(where: { $0.id == user.id }) ? "check" : "plus",
                    text: invitedMembers.contains(where: { $0.id == user.id }) ? "Inviting" : "Invite"
                )
            }
            .contentShape(.rect)
            //        .padding(.horizontal, 16)
            .onHighPriorityTap {
                searchText = ""
                inviteUser(user)
            }
        }
    }
}

// MARK: - Invited and Suggested
extension InviteMembersView {
    @ViewBuilder private func InvitedAndSuggested() -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if !invitedMembers.isEmpty {
                    VStack(spacing: 8) {
                        TextDivider("Inviting")
                        
                        VStack(spacing: 16) {
                            ForEach(invitedMembers) { user in
                                HStack {
                                    UserListCellView(uid: user.id, type: .large)
                                    
                                    Spacer()
                                    
                                    IconImage(name: "x-icon", color: .theme.iconSecondary, size: 16)
                                        .onHighPriorityTap {
                                            removeUser(user)
                                        }
                                }
                            }
                        }
                        
                    }
                    .padding(.bottom, 24)
                }
                
//                if !viewModel.suggestedMembers.isEmpty {
//                    SuggestedMembers()
//                }
            }
        }
        .padding(.horizontal, -16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
    
//    @ViewBuilder private func SuggestedMembers() -> some View {
//        VStack(spacing: 8) {
//            TextDivider("Suggested")
//            
//            VStack(spacing: 16) {
//                ForEach(viewModel.suggestedMembers.filter { !invitedMembers.contains($0) }) { user in
//                    UserCell(user: user)
//                }
//            }
//        }
//    }
}

// MARK: - Helper functions
extension InviteMembersView {
    private func updateUsers(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: userSearchViewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
    
    private func inviteUser(_ user: User) {
        if invitedMembers.contains(user) {
            removeUser(user)
        } else {
            invitedMembers.append(user)
        }
    }
    
    private func removeUser(_ user: User) {
        invitedMembers.removeAll(where: { $0.id == user.id })
    }
    
    private func searchUsers() {
        @Bindable var bindableVM = userSearchViewModel
        
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
//    InviteMembersView()
//}
