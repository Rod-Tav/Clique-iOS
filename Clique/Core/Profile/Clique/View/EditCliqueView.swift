//
//  EditCliqueView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/5/25.
//

import SwiftUI
import Toasts
import AdvancedList

struct EditCliqueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @State private var viewModel: EditCliqueProfileViewModel
    @State var membersPgVM: CliqueMembersPaginationViewModel
    
    @State private var showAddMembersSheet: Bool = false
    
    @State private var savingLoading: Bool = false
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    let cid: String
    var first5Members: [User]
    var numMembers: Int
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(clique: Clique, members: [User], numMembers: Int, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.cid = clique.id
        self.viewModel = .init(clique: clique)
        self.membersPgVM = .init(cid: clique.id, userStore, cliqueStore)
        self.first5Members = members
        self.numMembers = numMembers
    }
    
    private var canSave: Bool {
        !viewModel.cliqueName.isEmpty
    }
    
    var body: some View {
        @Bindable var bindableVM = viewModel
        
        VStack(spacing: 24) {
            TopBar()
            
            ScrollView {
                if let leaderId = clique?.leader, let leader = userStore.users[leaderId] {
                    EditCliqueHeader(
                        selectedPfpUIImage: $bindableVM.selectedPfpUIImage,
                        selectedCoverUIImage: $bindableVM.selectedCoverUIImage,
                        cliqueName: $bindableVM.cliqueName,
                        cliqueBio: $bindableVM.cliqueBio,
                        members: first5Members, // TODO: will need to change when we can remove members here
                        ogCliquePic: clique?.cliquePic,
                        ogCliqueBanner: clique?.cliqueBanner,
                        leader: leader
                    )
                }
                
                VStack(spacing: 16) {
                    HStack {
                        Text("\(pluralizeWithCount(count: numMembers + viewModel.invitedMembers.count, singular: "member"))")
                            .font(.body.bold())
                            .textPrimary()
                        
                        Spacer()
                        
                        SmallCTA(
                            type: .secondary,
                            leadingIcon: "plus",
                            text: "Add"
                        )
                        .onHighPriorityTap {
                            showAddMembersSheet = true
                        }
                    }
                    
                    if !viewModel.invitedMembers.isEmpty {
                        TextDivider("Inviting")
                        
                        VStack(spacing: 16) {
                            ForEach(viewModel.invitedMembers) { user in
                                HStack {
                                    MemberCell(user)
                                    
                                    Spacer()
                                    
                                    IconImage(name: "x-icon", color: .theme.iconSecondary, size: 16)
                                        .onHighPriorityTap {
                                            viewModel.invitedMembers.removeAll(where: { $0.id == user.id })
                                        }
                                }
                            }
                        }
                        
                        TextDivider("Already in Clique")
                    }
                    
                    AdvancedList(membersPgVM.items, listView: { users in
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
                }
                .padding(.horizontal, 24)
            }
            .sheet(isPresented: $showAddMembersSheet) {
                EditCliqueAddMembers(invitedMembers: $bindableVM.invitedMembers)
                    .padding(.horizontal, 16)
                    .presentationDetents([.fraction(0.999)])
                    .bottomSheetModifiers()
            }
        }
        .primaryBackground()
    }
    
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage(name: "x-icon", color: .theme.iconPrimary, size: 24)
                }
            },
            header: {
                Text("Edit Clique")
                    .font(.callout.weight(.semibold))
                    .textPrimary()
            },
            trailingIcon: {
                Button {
                    Task {
                        do {
                            savingLoading = true
                            let updatedClique = try await viewModel.editClique()
                            cliqueStore.updateClique(updatedClique, forceUpdateURL: (viewModel.selectedPfpUIImage != nil || viewModel.selectedCoverUIImage != nil))
                            savingLoading = false
                            dismiss()
//                            editUserProfileCoordinator.triggerRefresh.toggle()
                        } catch {
                            savingLoading = false
                            presentToast(Toasts.somethingWentWrong)
                        }
                    }
                } label: {
                    if savingLoading {
                        CliqueProgressView(size: 24)
                    } else {
                        IconImage(name: "check", color: canSave ? .theme.iconPrimary : .theme.iconTertiary, size: 24)
                    }
                }
                .disabled(!canSave)
            }
        )
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func MemberList(_ users: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: users)
        }
    }
    
    @ViewBuilder private func MemberCell(_ user: User) -> some View {
        UserListCellView(uid: user.id, type: .large)
            .maxWidth(.leading)
    }
    
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateMembers(.refresh)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateMembers(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: membersPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}

// search bar doesn't show cancel/done unless this is a struct idk why
fileprivate struct EditCliqueAddMembers: View {
    @Environment(UserStore.self) private var userStore
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    @Binding var invitedMembers: [User]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Members")
                .font(.callout.weight(.semibold))
                .textPrimary()
            
            InviteMembersView(userStore: userStore, searchText: $searchText, isSearchFocused: $isSearchFocused, invitedMembers: $invitedMembers)
        }
    }
}

//#Preview {
//    EditCliqueView(type: .creator, members: .constant([]))
//}
