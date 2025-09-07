//
//  InboxView.swift
//  Clique
//
//  Created by Quinn Liu on 2/1/25.
//

import SwiftUI
import AdvancedList
import Toasts

struct InboxView: View {
    /// Environments
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
//    @Environment(InboxCoordinator.self) private var inboxCoordinator
    
    @State private var followRequestsPaginationVM: FollowRequestsPaginationViewModel
    
    /// Clique invites pagination
    @State private var cliqueInvitesVM: CliqueInvitesViewModel
    @State private var cliquesListState: ListState = .loading
    @State private var cliquesPaginationState: AdvancedListPaginationState = .idle
    
    @State private var acceptedCliqueInviteIds = [String]() // clique invite ids
    
    @Binding var hasInboxNotification: Bool
    
    init(hasInboxNotification: Binding<Bool>, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self._hasInboxNotification = hasInboxNotification
        self.followRequestsPaginationVM = .init(userStore)
        self.cliqueInvitesVM = .init(userStore, cliqueStore)
    }
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableVm = tabViewCoordinator
        
//        TabNavigationStack(path: $bindableVm.searchNavigationPath) {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    TopBar()
                    
                    Divider()
                }
                
                if (!(cliquesListState == .loading || followRequestsPaginationVM.followListState == .loading)) && cliqueInvitesVM.items.isEmpty && followRequestsPaginationVM.items.isEmpty {
                    EmptyInbox()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if !cliqueInvitesVM.items.isEmpty {
                                CliqueInvitesListView()
                            }
                            
                            FollowRequestsListView(inSheet: true)
                                .environment(followRequestsPaginationVM)
                                .opacity(followRequestsPaginationVM.items.isEmpty && followRequestsPaginationVM.page > 0 ? 0 : 1)
                        }
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .refreshable {
                        refresh()
                    }
                    .bottomTabBarPadding()
                }
            }
            //        .onChange(of: viewModel.triggerPresentToast) {
            //            presentToast(Toasts.somethingWentWrong)
            //        }
            .onAppear {
                Task {
                    guard cliquesListState == .loading else { return }
                    
                    await updateCliqueInvites(.loadFirstPage)
                }
            }
            .onDisappear {
                if hasInboxNotification {
                    trigger(.checkInboxNotifications)
                }
            }
            .primaryBackground()
            .onChange(of: [cliqueInvitesVM.items.count, followRequestsPaginationVM.items.count], initial: true) { _, newValue in
                // Only update to true when we have items, don't reset to false during initial loading
                if newValue.contains(where: { $0 > 0 }) {
                    hasInboxNotification = true
                } else if cliquesListState != .loading && followRequestsPaginationVM.followListState != .loading {
                    // Only set to false after we've finished loading data
                    hasInboxNotification = false
                }
            }
//        }
    }
    
    // MARK: - Top Bar
    @ViewBuilder private func TopBar() -> some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                IconImage("x-icon", color: .theme.iconPrimary, size: 24)
            }
//            BackButton(color: Color.theme.iconPrimary, size: 24)
            
            Spacer()
            
            Text("Inbox")
                .font(.headline)
                .textPrimary()
            
            Spacer()
            
            Button {
                refresh()
            } label: {
                IconImage("refresh", color: .theme.iconPrimary, size: 24)
            }
        }
        .maxWidth(.leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func refresh() {
        guard cliquesPaginationState == .idle, followRequestsPaginationVM.followPaginationState == .idle else { return }
        
        followRequestsPaginationVM.triggerRefresh.toggle()
        
        DispatchQueue.main.async { // no idea
            Task {
                // Clear cache for notifications/invites
                await CacheControl.shared.refreshNotifications()
                
                await updateCliqueInvites(.refresh)
            }
        }
    }
    
    // MARK: - Clique Invitations -
    
    // MARK: - Clique Invitation List View
    @ViewBuilder private func CliqueInvitesListView() -> some View {
        VStack(spacing: 8) {
            TextDivider("Clique Invitations")
            
            AdvancedList(cliqueInvitesVM.items, listView: { invites in
                CliqueInvitesList(invites)
            }, content: { invite in
                CliqueInviteCell(invite)
            }, listState: cliquesListState, emptyStateView: {
                EmptyView()
            }, errorStateView: { _ in
                SomethingWentWrong {
                    cliquesListState = .loading
                    await updateCliqueInvites(.refresh)
                }
            }, loadingStateView: {
                CliqueProgressView()
                    .infiniteFrame()
            })
        }
    }
    
    // MARK: - Clique Invites List
    @ViewBuilder private func CliqueInvitesList(_ invites: AdvancedList.Rows) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVStack(spacing: 16, content: invites)
            
            if !cliqueInvitesVM.done {
                TextButton("See More") {
                    Task { await updateCliqueInvites(.loadNextPage) }
                }
            }
        }
    }
    // MARK: - Clique Invite Cell
    @ViewBuilder private func CliqueInviteCell(_ invite: CliqueInvite) -> some View {
        let clique = invite.clique
        let fromUserPfp = invite.fromUser.profilePic
        let fromUserFirstName = invite.fromUser.firstname
        
        HStack(spacing: 16) {
            Button {
                dismiss()
                tabViewCoordinator.navigate(to: clique)
            } label: {
                CliqueListCellView(cid: clique.id, type: .cliqueInvite(fromUserPfp: fromUserPfp, fromUserFirstName: fromUserFirstName))
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if acceptedCliqueInviteIds.contains(invite.id) {
                    SmallCTA(type: .tertiary, leadingIcon: "check", text: "Accepted") {
                        // TODO: leave clique
                    }
                } else {
                    SmallCTA(type: .primary, text: "Accept") {
                        haptics(.light)
                        Task {
                            do {
                                acceptedCliqueInviteIds.append(invite.id)
                                
                                AppService.decrementAppBadge()
                                
                                userStore.users[userStore.currentUserId!]?.numCliques += 1
                                
                                cliqueStore.cliques[clique.id]?.numMembers += 1
                                cliqueStore.cliques[clique.id]?.relationship = .member
                                
                                try await CliqueService.acceptCliqueInvite(.init(path: .init(cliqueInviteId: invite.id)))
                                
                                // Clear cache for notifications after accepting invite
                                await CacheControl.shared.refreshNotifications()
                                
                                trigger(.refreshUserCliques) // update user cliques tab
                            } catch {
                                acceptedCliqueInviteIds.removeAll(where: { $0 == invite.id })
                                presentToast(Toasts.somethingWentWrong)
                            }
                        }
                    }
                }
                
                Menu {
                    Button {
                        Task {
                            do {
                                try await CliqueService.declineCliqueInvite(.init(path: .init(cliqueInviteId: invite.id)))
                                
                                // Clear cache for notifications after declining invite
                                await CacheControl.shared.refreshNotifications()
                                
                                AppService.decrementAppBadge()
                                
                                cliqueInvitesVM.items.removeAll(where: { $0.id == invite.id })
                            } catch {
                                presentToast(Toasts.somethingWentWrong)
                            }
                        }
                    } label: {
                        Text("Decline")
                    }
                    
//                    BlockButton {
//                        // TODO: block
//                    }
                } label: {
                    TinyButton()
                }
            }
        }
    }
    
    // MARK: - Pagination funciton
    private func updateCliqueInvites(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: cliqueInvitesVM,
            listState: $cliquesListState,
            paginationState: $cliquesPaginationState
        )
    }
    
    // MARK: - Empty Inbox
    @ViewBuilder private func EmptyInbox() -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                IconImage("sun", color: .theme.iconPrimary, size: 32) // TODO: stroke
                
                Text("You're all caught up!")
                    .font(.footnote)
                    .textPrimary()
            }
            
//            CliqueButton(type: .tertiary, text: "Dismiss") {
//                dismiss()
//            }
        }
        .infiniteFrame()
        .bottomTabBarPadding()
    }
}

//#Preview {
//    @Previewable @State var viewModel: NotificationsViewModel = NotificationsViewModel()
//    @Previewable @State var showInboxSheet: Bool = true
//    NotificationsInboxView(viewModel: $viewModel, showInboxSheet: $showInboxSheet)
//}
