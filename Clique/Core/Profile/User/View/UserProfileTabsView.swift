//
//  UserProfileTabsView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/22/24.
//

import SwiftUI
import Toasts

struct UserProfileTabsView: View {
    @Environment(\.presentToast) private var presentToast
    @Environment(\.dismiss) private var dismiss
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var viewModel = UserProfileViewModel()
    @State private var followVM = FollowUserViewModel()
    @State private var coordinator = ProfileTabSwitcherCoordinator()
    
    @State private var showReportCover: Bool = false
    @State private var showBlockAlert: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var showAddFriendsSheet: Bool = false
    @State private var showInboxSheet: Bool = false
    @State private var showPfp: Bool = false
    
    private var showPrivate: Bool {
        return user?.isPrivate ?? false && !(user?.id == userStore.currentUserId) && userStore.users[userId]?.relationship != .following
    }
    
    let userId: String
    var isCurrentUser: Bool = false
    
    private var user: User? {
        userStore.users[userId]
    }
    
//    init(userId: String, isCurrentUser: Bool = false) {
//        self.userId = userId
//        self.viewModel = .init(user: user)
//        self.isCurrentUser = isCurrentUser
//    }
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableVm = viewModel
        
        Group {
            if #available(iOS 18.0, *) {
                HeaderPageScrollView(
                    displaysSymbols: true,
                    header: {
                        UserProfileExpandedHeader()
                    },
                    labels: {
                        PageLabel(title: UserProfileTab.cliques.title, symbolImage: UserProfileTab.cliques.icon)
                        PageLabel(title: UserProfileTab.collections.title, symbolImage: UserProfileTab.collections.icon)
                    },
                    pages: {
                        if showPrivate {
                            PrivateViewForScrollContainer()
                            PrivateViewForScrollContainer()
                        } else {
                            UserCliquesView(uid: userId, cliqueStore)
                                .environment(viewModel)
                                .environment(coordinator)
                                .padding(.horizontal, 16)
                            
                            UserProfileCollectionsView(uid: userId, collectionStore, collectionImageStore)
                                .environment(viewModel)
                                .environment(coordinator)
                                .padding(.horizontal, 16)
                        }
                    },
                    onRefresh: {
                        refreshAll()
                    }
                )
            } else {
                // iOS 17 fallback
                ProfileTabSwitcher2(
                    smallHeaderView: UserProfileCollapsedHeader(),
                    largeHeaderView: UserProfileExpandedHeader(),
                    tabs: UserProfileTab.allCases,
                    ignoresSafeArea: false,
                    panDisabled: appCoordinator.lookingAtUserProfileFromCollectionDetail
                ) {
                    if showPrivate {
                        PrivateView()
                    } else {
                        TabContent(id: 0) {
                            UserCliquesView(uid: userId, cliqueStore)
                                .environment(viewModel)
                                .padding(.horizontal, 16)
                        }
                        
                        TabContent(id: 1) {
                            UserProfileCollectionsView(uid: userId, collectionStore, collectionImageStore)
                                .environment(viewModel)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .environment(coordinator)
            }
        }
        .sheet(isPresented: $showAddFriendsSheet) {
            AddContactsView()
                .bottomSheetModifiers()
        }
        .fullScreenCover(isPresented: $showEditProfile) {
            if let user {
                EditUserProfileView(user: user)
            }
        }
        .fullScreenCover(isPresented: $showPfp) {
            if let user {
                ExpandedPfpView {
                    UserPfpAsyncView(pfp: user.profilePic, size: 256, quality: .high)
                }
            }
        }
        .onAppear {
            guard let user, let cuid = userStore.currentUserId, user.id != cuid, userStore.users[user.id]?.relationship == nil else { return }
            
            Task {
                do {
                    let relationship = try await viewModel.getFollowStatus(uid: user.id)
                    userStore.users[userId]?.relationship = relationship
                } catch {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
        .bottomTabBarPadding()
        .primaryBackground()
//        .onChange(of: editUserProfileCoordinator.triggerRefresh) {
//            refreshUserInfo()
//        }
    }

    // MARK: - Header Icons
    @ViewBuilder private func HeaderLeadingIcon() -> some View {
        if tabViewCoordinator.activeTab == .profile, tabViewCoordinator.profileNavigationPath.count < 2 {
            HeaderTrailingIcon()
                .hidden()
        } else {
            BackButton(size: 24) {
                dismiss()
                appCoordinator.lookingAtUserProfileFromCollectionDetail = false
            }
        }
    }
    
    @ViewBuilder private func HeaderTrailingIcon() -> some View {
        if isCurrentUser {
            HStack(spacing: 12) {
                NavigationLink(value: "NotificationsCenter") {
                    IconImage(name: "inbox", color: .theme.iconPrimary, size: 24)
                        .overlayTopRightNotification(when: tabViewCoordinator.hasNotification)
                }
                
                if #unavailable(iOS 18.0) {
                    Button {
                        refreshAll()
                    } label: {
                        IconImage(name: "refresh", color: .theme.iconPrimary, size: 24)
                    }
                }
            }
        } else {
            Menu {
                if #unavailable(iOS 18.0) {
                    RefreshMenuButton {
                        refreshAll()
                    }
                }
                
                if userStore.currentUserId != userId {
                    ReportButton {
                        showReportCover = true
                    }
                    
                    BlockButton {
                        showBlockAlert = true
                    }
                }
            } label: {
                IconImage(name: "ellipsis", color: .theme.iconPrimary, size: 24)
            }
            .buttonStyle(.noHighlight)
            .fullScreenCover(isPresented: $showReportCover) {
                ReportView(showReport: $showReportCover, objectId: userId, reportType: .user)
            }
            .alert(isPresented: $showBlockAlert) {
                Alert(
                    title: Text("Are you sure you want to block this user?"),
                    message: Text("You can unblock them later from your profile settings."),
                    primaryButton: .destructive(Text("Block")) {
                        Task {
                            do {
                                try await UserService.blockUser(.init(path: .init(userId: userId)))
                            } catch {
                                presentToast(Toasts.somethingWentWrong)
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

// MARK: - Headers
extension UserProfileTabsView {
    @ViewBuilder private func UserProfileCollapsedHeader() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: HeaderLeadingIcon,
            header: CollapsedHeaderContent,
            trailingIcon: HeaderTrailingIcon
        )
        .padding(16)
    }
    
    @ViewBuilder private func CollapsedHeaderContent() -> some View {
        if let user {
            VStack(spacing: 2) {
                Text(user.fullname)
                    .textPrimary()
                    .multilineTextAlignment(.center)
                    .font(.callout.bold())
                
                Text("@\(user.username)")
                    .textSecondary()
                    .multilineTextAlignment(.center)
                    .font(.caption)
            }
        }
    }
    
    @ViewBuilder private func UserProfileExpandedHeader() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TopAppBar(
                type: .small,
                leadingIcon: HeaderLeadingIcon,
                header: {},
                trailingIcon: HeaderTrailingIcon
            )
            .padding(.vertical, 12)
            
            VStack(alignment: .leading, spacing: 12) {
                UserPfpAndPinnedCliques()
                
                NameAndHandle()
                
                if let user, !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.footnote)
                        .textPrimary()
                }
                
                UserStats()
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .contentShape(.rect)
    }
}


// MARK: - Pfp and pinned cliques
extension UserProfileTabsView {
    @ViewBuilder private func UserPfpAndPinnedCliques() -> some View {
        HStack(spacing: 0) {
            if let user {
                UserPfpAsyncView(pfp: user.profilePic, size: 64, quality: .low)
                    .onTapGesture {
                        showPfp = true
                    }
                
                // TODO: pinned cliques
//                Spacer()
//                
//                HStack(spacing: -6) {
//                    ForEach(user.pinnedCliques ?? CliqueService.fetchUserPinnedCliques(uid: user.id)) { clique in
//                        NavigationLink(value: clique) {
//                            CliquePfpView(pfp: clique.cliquePic, type: .pinnedCliques)
//                        }.buttonStyle(.noHighlight)
//                    }
//                }
            }
        }
    }
    
    @ViewBuilder private func NameAndHandle() -> some View {
        if let user {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Text(user.fullname)
                            .font(.title2.bold())
                            .kerning(0.0748)
                            .textPrimary()
                        
                        if showPrivate {
                            IconImage(name: "lock", color: .theme.iconPrimary, size: 16)
                        }
                    }
                    
                    Spacer()
                    
                    if isCurrentUser {
                        CurrentUserCTAs()
                    } else {
                        FollowRelationButton()
                    }
                }
                
                Text("@\(user.username)")
                    .font(.caption)
                    .textSecondary()
            }
        }
    }
    
    @ViewBuilder private func UserStats() -> some View {
        HStack(spacing: 0) {
            // TODO: something happens when you hit this, maybe sheet like clique members
            if let user {
                Button {
                    if coordinator.selectedTab == 0 {
                        haptics(.medium)
                    } else {
                        withAnimation {
                            coordinator.selectedTab = 0
                        }
                    }
                } label: {
                    UserStatView(value: user.numCliques, title: pluralize(count: user.numCliques, singular: "Clique"))
                }
                
                Text(" • ")
                    .font(.caption)
                    .textSecondary()
                
                NavigationLink(value: FollowersFollowing.followers(user)) {
                    UserStatView(value: user.numFollowers, title: pluralize(count: user.numFollowers, singular: "Follower"))
                }
                .disabled(showPrivate)
                
                Text(" • ")
                    .font(.caption)
                    .textSecondary()
                
                NavigationLink(value: FollowersFollowing.following(user)) {
                    UserStatView(value: user.numFollowing, title: "Following")
                }
                .disabled(showPrivate)
            }
        }
    }
    
    // MARK: - Follow Button / Current user CTAs
    @ViewBuilder private func FollowRelationButton() -> some View {
        if let user, let relationship = user.relationship {
            UserFollowButton(relationship: relationship) {
                let oldUser = user
                Task {
                    do {
                        switch relationship {
                        case .following:
                            try await FollowUserViewModel.unfollow(userId, userStore)
                        case .requested:
                            try await FollowUserViewModel.unrequest(userId, userStore)
                        case .unrelated:
                            try await FollowUserViewModel.follow(userId, isPrivate: user.isPrivate, userStore)
                        }
                    } catch {
                        userStore.users[userId] = oldUser
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func CurrentUserCTAs() -> some View {
        HStack(spacing: 8) {
            SmallCTA(
                type: .secondary,
                leadingIcon: "pen",
                text: "Edit",
                action: {
                    showEditProfile = true
                }
            )
            
            // TODO: share
//            SmallCTA(
//                type: .secondary,
//                leadingIcon: "share",
//                action: {
//                    print("sharing profile")
//                }
//            )
            
            SmallCTA(
                type: .secondary,
                leadingIcon: "setting",
                action: {
                    tabViewCoordinator.navigate(to: "UserSettings")
                }
            )
        }
    }
}

// MARK: - Private account
extension UserProfileTabsView {
    @ViewBuilder private func PrivateView() -> some View {
        VStack(spacing: 8) {
            IconImage(name: "2-user", color: .theme.iconPrimary, size: 32)
            
            if let user {
                Text("\(user.firstname) has a private account.\nFollow them to see their flicks!")
                    .textPrimary()
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
        .containerRelativeFrame(.horizontal)
        .disabled(true)
    }
    
    @ViewBuilder private func PrivateViewForScrollContainer() -> some View {
        VStack(spacing: 8) {
            IconImage(name: "2-user", color: .theme.iconPrimary, size: 32)
            
            if let user {
                Text("\(user.firstname) has a private account.\nFollow them to see their flicks!")
                    .textPrimary()
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
        .infiniteFrame()
        .disabled(true)
    }
}

// MARK: - Helper Functions
extension UserProfileTabsView {
    private func refreshAll() {
        // Check if already refreshing to prevent concurrent refreshes
        guard !viewModel.isRefreshing else { return }
        
        Task {
            viewModel.isRefreshing = true
            defer { viewModel.isRefreshing = false }
            
            do {
                // Clear cache for this user profile
                await CacheControl.shared.refreshUserProfile(userId)
                
                let updatedUser = try await UserService.getUserById(userId)
                
                if !(updatedUser.id == userStore.currentUserId) {
                    let relationship = try await viewModel.getFollowStatus(uid: updatedUser.id)
                    
                    userStore.users[updatedUser.id]?.relationship = relationship
                }
                
                userStore.updateUser(updatedUser, forceUpdateURL: true)
                
                viewModel.triggerRefresh.toggle()
                coordinator.scrollToTop.toggle()
            } catch {
                if !(error is CancellationError) {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
    }
    
//    private func refreshUserInfo() {
//        Task {
//            do {
//                let updatedUser = try await UserService.getUserById(userId)
//                
//                if !(updatedUser.id == userStore.currentUserId) {
//                    let relationship = try await viewModel.getFollowStatus(uid: updatedUser.id)
//                    
//                    userStore.users[updatedUser.id]?.relationship = relationship
//                }
//                
//                await MainActor.run {
//                    await userStore.updateUser(updatedUser)
//                }
//            } catch {
//                await MainActor.run {
//                    presentToast(Toasts.somethingWentWrong)
//                }
//            }
//        }
//    }
}


#Preview {
    UserProfileTabsView(userId: User.MOCK_USERS[0].id)
        .environment(TabViewCoordinator())
}
