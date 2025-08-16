//
//  InviteMembersScreen.swift
//  Clique
//
//  Created by Rod Tavangar on 1/16/25.
//

import SwiftUI
import AdvancedList

struct InviteMembersScreen: View {
//    @Environment(NetworkMonitor.self) private var networkMonitor
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(CliqueCreatorFlowViewModel.self) private var viewModel
    
//    @State private var userSearchViewModel: UserSearchPaginationViewModel
//    
//    @State private var listState: ListState = .items
//    @State private var paginationState: AdvancedListPaginationState = .idle
//    @State private var isScrollAtBottom: Bool = false
    
//    @State private var searchTask: Task<Void, Never>?
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
//    @State private var debouncer = Debouncer()
    
    private var invitedMembers: [User] {
        viewModel.invitedMembers
    }
    
//    init(userStore: UserStore) {
//        self.userSearchViewModel = .init(userStore: userStore)
//    }
    
    // TODO: sometimes hitting x acts like cancel
    var body: some View {
        @Bindable var bindableVM = viewModel
        
        VStack(spacing: 24) {
            TopTitle(
                title: "Invite Members to your Clique",
                description: "You can always invite more people once the Clique is created."
            )
            .ignoresSafeArea(.keyboard)
            
//            SearchBar(
//                searchText: $searchText,
//                isSearchFocused: $isSearchFocused,
//                buttonText: invitedMembers.isEmpty ? "Cancel" : "Done"
//            )
//            
//            if !isSearchFocused, searchText.isEmpty {
//                InvitedAndSuggested()
//            } else {
//                AdvancedList(userSearchViewModel.items, listView: { users in
//                    UserList(users: users)
//                }, content: { userID in
//                    if let user = userStore.users[userID] {
//                        UserCell(user: user)
//                    }
//                }, listState: listState, emptyStateView: {
////                    SearchUsersEmptyStateView(/*show: searchText.count >= 3*/)
//                    if searchText.isEmpty {
//                        InvitedAndSuggested()
//                    } else {
//                        SearchUsersEmptyStateView()
//                    }
//                }, errorStateView: { _ in
//                    SearchUsersErrorStateView(listState: $listState, refresh: { await updateUsers(.refresh) })
//                }, loadingStateView: {
//                    SearchUsersLoadingStateView()
//                })
//                .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateUsers(.loadNextPage) } }) { })
//            }
            InviteMembersView(userStore: userStore, searchText: $searchText, isSearchFocused: $isSearchFocused, invitedMembers: $bindableVM.invitedMembers)
        }
        .onChange(of: viewModel.triggerDismissKeyboard) {
            guard coordinator.currentIconStep == 1 else { return }
            isSearchFocused = false
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: invitedMembers, initial: true) {
            guard coordinator.currentIconStep == 1 else { return }
            coordinator.highlightNextBar = !invitedMembers.isEmpty
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
        .frameTop()
    }
}

// MARK: - Bottom Button
extension InviteMembersScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: "Done",
            buttonEnabled: !invitedMembers.isEmpty
        ) { bottomButtonAction() }
    }
    
    private func bottomButtonAction() {
        coordinator.highlightNextBar = false
        coordinator.currentIconStep += 1
        coordinator.path.append(2)
    }
}

#Preview {
    InviteMembersScreen()
        .padding(.top, 24)
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
        .frameTop()
        .environment(TopIconFlowCoordinator())
        .environment(CliqueCreatorFlowViewModel())
}
