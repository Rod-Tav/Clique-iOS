//
//  CliqueProfileView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/25/24.
//

import SwiftUI
import Toasts

struct CliqueProfileView: View {
    @Environment(\.presentToast) private var presentToast
    @Environment(\.dismiss) private var dismiss
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var viewModel: CliqueProfileViewModel
    @State private var coordinator = ProfileTabSwitcherCoordinator()
    
    @State private var showEditProfile: Bool = false
    @State private var showCliqueMembers: Bool = false
    @State private var showInboxView: Bool = false
    @State private var showReportCover: Bool = false
    @State private var showBlockAlert: Bool = false
    @State private var showCliquePfp: Bool = false
    @State private var showCliqueBanner: Bool = false
    
    let cid: String
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(cid: String) {
        self.cid = cid
        self.viewModel = .init(cid: cid)
    }
    
    // MARK: - Body
    var body: some View {
        if let clique {
            Group {
                if #available(iOS 18.0, *) {
                    HeaderPageScrollView(
                        displaysSymbols: true,
                        ignoreTopSafeArea: true,
                        header: {
                            CliqueProfileExpandedHeader()
                        },
                        labels: {
                            PageLabel(title: CliqueProfileTab.recents.title, symbolImage: CliqueProfileTab.recents.icon)
                            PageLabel(title: CliqueProfileTab.collections.title, symbolImage: CliqueProfileTab.collections.icon)
                        },
                        pages: {
                            CliqueRecentsView(cid: clique.id, collectionStore, collectionImageStore, userStore, cliqueStore)
                                .environment(viewModel)
                                .environment(coordinator)
                            
                            CliqueProfileCollectionsView(cid: clique.id, collectionStore, collectionImageStore)
                                .environment(viewModel)
                                .environment(coordinator)
                                .padding(.horizontal, 24)
                        },
                        onRefresh: {
                            refreshAll()
                        }
                    )
                } else {
                    // iOS 17 fallback
                    ProfileTabSwitcher2(
                        smallHeaderView: CliqueProfileCollapsedHeader(),
                        largeHeaderView: CliqueProfileExpandedHeader(),
                        tabs: CliqueProfileTab.allCases
                    ) {
                        TabContent(id: 0) {
                            CliqueRecentsView(cid: clique.id, collectionStore, collectionImageStore, userStore, cliqueStore)
                                .environment(viewModel)
                        }
                        
                        TabContent(id: 1) {
                            CliqueProfileCollectionsView(cid: clique.id, collectionStore, collectionImageStore)
                                .environment(viewModel)
                                .padding(.horizontal, 24)
                        }
                    }
                    .environment(coordinator)
                }
            }
            .sheet(isPresented: $showCliqueMembers) {
                CliqueMembersListSheetView(cid: clique.id, userStore, cliqueStore)
                    .presentationDetents([.fraction(0.999)])
                    .bottomSheetModifiers()
            }
            //        .tabSheet(isPresented: $showCliqueMembers) {
            //            CliqueMembersListSheetView(clique: clique)
            //        }
            .onAppear {
                Task {
                    guard viewModel.firstXMembers.count < min(clique.numMembers, 5) else { return }
                    
                    do {
                        try await viewModel.fetchCliqueFirstXMembers(count: 5, total: clique.numMembers, userStore, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
            .fetchCliqueRelationship(cid: clique.id)
            .fullScreenCover(isPresented: $showReportCover) {
                ReportView(showReport: $showReportCover, objectId: clique.id, reportType: .clique)
            }
            .fullScreenCover(isPresented: $showCliquePfp) {
                ExpandedPfpView {
                    CliquePfpAsyncView(pfp: clique.cliquePic, type: .expanded, hasBorder: false, quality: .high)
                }
            }
            .fullScreenCover(isPresented: $showCliqueBanner) {
                ExpandedPfpView {
                    ExpandedBannerAsyncImage(banner: clique.cliqueBanner, type: .clique, quality: .high, showGradient: false)
                }
            }
            .onReceive(of: .refreshCliqueFeed) { noti in
                guard noti.checkEquals(cid) else { return }
                
                print("refreshing clique feed")
                refreshTabs()
            }
            .onAppear {
                appCoordinator.activeCliqueFeeds.insert(cid)
            }
            .onDisappear {
                appCoordinator.activeCliqueFeeds.remove(cid)
            }
            .fullScreenCover(isPresented: $showEditProfile) {
                EditCliqueView(clique: clique, members: viewModel.firstXMembers, numMembers: clique.numMembers, userStore, cliqueStore)
            }
        }
    }
}

// MARK: - Headers
extension CliqueProfileView {
    @ViewBuilder private func CliqueProfileCollapsedHeader() -> some View {
        if let clique {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    CollapsedBannerAsyncImage(banner: clique.cliqueBanner, quality: .high)
                    
                    TopAppBar(
                        type: .small,
                        leadingIcon: {
                            BackButton(color: .theme.white, size: 24)
                        },
                        header: {
                            CliquePill(clique.id, type: .cliqueProfile)
                        },
                        trailingIcon: {
                            EllipsisMenu()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    @ViewBuilder private func CliqueProfileExpandedHeader() -> some View {
        if let clique {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .top) {
                        ExpandedBannerAsyncImage(banner: clique.cliqueBanner, type: .clique, quality: .high)
                            .onTapGesture {
                                showCliqueBanner = true
                            }
                        
                        TopAppBar(
                            type: .small,
                            leadingIcon: {
                                BackButton(color: .theme.white, size: 24)
                            },
                            header: {},
                            trailingIcon: {
                                EllipsisMenu()
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, safeAreaInsets.top)
                    }
                    
                    HStack(spacing: 0) {
                        CliquePfpAsyncView(pfp: clique.cliquePic, type: .cliqueProfile, quality: .low)
                            .onTapGesture {
                                showCliquePfp = true
                            }
                        
                        Spacer()
                        
                        if !viewModel.firstXMembers.isEmpty {
                            Button {
                                showCliqueMembers = true
                            } label: {
                                CliqueCircularMembersView(members: viewModel.firstXMembers, type: .cliqueProfile)
                            }.buttonStyle(.noHighlight)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, -CliquePfpViewType.cliqueProfile.size.height / 2)
                    .padding(.bottom, 12)
                }
                
                CliqueInfo()
                    .if(.iOS18) { view in
                        view
                            .padding(.bottom, -32)
                    }
                    .if(!.iOS18) { view in
                        view
                            .padding(.bottom,  24)
                    }
            }
        }
    }
}

// MARK: - Info
extension CliqueProfileView {
    /// All profile info of the clique
    @ViewBuilder private func CliqueInfo() -> some View {
        if let clique {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(clique.name)")
                                .font(.title2.bold())
                            
                            Spacer()
                            
                            // TODO: unfollow clique
//                            if let relation = cliqueStore.cliques[cid]?.relationship {
//                                CliqueFollowButton(relationship: relation) {
//                                    print("tapped")
//                                }
//                            }
                            
                            if isInClique(cid: clique.id, cliqueStore) {
                                Spacer()
                                
                                SmallCTA(
                                    type: .secondary,
                                    leadingIcon: "pen",
                                    text: "Edit",
                                    action: {
                                        showEditProfile = true
                                    }
                                )
                            }
                        }
                        
                        CliqueLeaderAndCreation()
                    }
                    
                    if !clique.bio.isEmpty {
                        Text(clique.bio)
                            .font(.caption)
                            .textPrimary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    CliqueStats()
                }
                
                if let relationship = clique.relationship, relationship.isInClique {
                    HStack(spacing: 12) {
                        CliqueButton(
                            type: .primary,
                            leadingIcon: "plus",
                            text: "Create",
                            fullWidth: true
                        ) {
                            tabViewCoordinator.startCreateFlow(for: clique)
                        }
                        
                        // TODO: specific clique notifications
//                        CliqueButton(
//                            type: .tertiary,
//                            leadingIcon: "inbox",
//                            text: /*hasNotifications ? notifications.count : */"Activity"
//                        ) {
////                            if hasNotifications {
////                            } else {
//
//                            showInboxView = true
//                            
//                        }
//                        .fixedSize(horizontal: true, vertical: true)
                    }
                    .maxWidth()
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    /// Line for leader and creation date
    @ViewBuilder private func CliqueLeaderAndCreation() -> some View {
        if let clique {
            HStack(spacing: 12) {
                if let leaderId = clique.leader, let leader = userStore.users[leaderId] {
                    NavigationLink(value: leader) {
                        HStack(spacing: 2) {
                            IconImage("crown-leader", color: Color.theme.iconSecondary, size: 14)
                            
                            Text("@\(leader.username)")
                                .font(.caption)
                                .textSecondary()
                        }
                    }.buttonStyle(.noHighlight)
                }
                
                HStack(spacing: 4) {
                    IconImage("calendar", color: Color.theme.iconSecondary, size: 14)
                    
                    Text("est. \(formatDateMMMMyyyy(clique.creation))")
                        .font(.caption)
                        .textSecondary()
                }
            }
        }
    }
    
    /// Members, aura, flicks
    @ViewBuilder private func CliqueStats() -> some View {
        if let clique {
            HStack(spacing: 0) {
                Button {
                    showCliqueMembers = true
                } label: {
                    UserStatView(value: clique.numMembers, title: clique.numMembers == 1 ? "Member" : "Members")
                }
                
//                Text(" • ")
//                    .font(.caption)
//                    .textSecondary()
//                
//                UserStatView(value: clique.numAura, title: "Aura")
                
//                Text(" • ")
//                    .font(.caption)
//                    .textSecondary()
//                
//                UserStatView(value: clique.numFlicks, title: clique.numFlicks == 1 ? "Flick" : "Flicks")
            }
        }
    }
}

// MARK: - Ellipsis Menu
extension CliqueProfileView {
    @ViewBuilder private func EllipsisMenu() -> some View {
        Menu {
            if #unavailable(iOS 18.0) {
                RefreshMenuButton {
                    refreshAll()
                }
            }
            
            // TODO: Settings
            //                if let relation = cliqueStore.cliques[cid]?.relationship, relation == .leader {
            //                    Button("Settings", action: { })
            //                }
            
            if isInClique(cid: cid, cliqueStore) {
                EditMenuButton {
                    showEditProfile = true
                }
            }
            
            ReportButton {
                showReportCover = true
            }
            
            if !isInClique(cid: cid, cliqueStore) {
                BlockButton {
                    showBlockAlert = true
                }
            }
        } label: {
            EllipsisImage(color: .theme.white, size: 24)
        }
        .alert(isPresented: $showBlockAlert) {
            Alert(
                title: Text("Are you sure you want to block this clique?"),
                message: Text("You can unblock them later from your profile settings."),
                primaryButton: .destructive(Text("Block")) {
                    Task {
                        do {
                            try await CliqueService.blockClique(.init(path: .init(cliqueId: cid)))
                        } catch {
                            presentToast(Toasts.somethingWentWrong)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func refreshTabs() {
        viewModel.triggerRefresh.toggle()
        coordinator.scrollToTop.toggle()
    }
    
    private func refreshAll() {
        // Check if already refreshing to prevent concurrent refreshes
        guard !viewModel.isRefreshing else { return }
        
        Task {
            viewModel.isRefreshing = true
            defer { viewModel.isRefreshing = false }
            
            do {
                let updatedClique = try await CliqueService.getCliqueById(id: cid)
                
                if viewModel.firstXMembers.count < min(updatedClique.numMembers, 5) {
                    do {
                        try await viewModel.fetchCliqueFirstXMembers(count: 5, total: updatedClique.numMembers, userStore, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
                
                let relationship = try await CliqueService.getCliqueRelationship(.init(path: .init(cliqueId: updatedClique.id)))
                
                cliqueStore.cliques[updatedClique.id]?.relationship = relationship
                
                cliqueStore.updateClique(updatedClique, forceUpdateURL: true)
                
                refreshTabs()
            } catch {
                if !(error is CancellationError) {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
    }
}

#Preview {
    CliqueProfileView(cid: Clique.MOCK_CLIQUES[7].id)
        .environment(TabViewCoordinator())
        .environment(UserStore())
        .environment(CliqueStore())
        .environment(CollectionStore())
}
