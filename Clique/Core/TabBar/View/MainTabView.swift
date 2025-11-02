//
//  MainTabView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/9/24.
//

import SwiftUI
import Toasts
import Photos

/// The main authenticated app experience with tab-based navigation.
///
/// This view serves as the container for the entire authenticated user experience,
/// managing the tab-based navigation system and coordinating between different
/// major app features. It orchestrates complex interactions between tabs,
/// upload flows, and global app state.
///
/// ## Architecture Overview
/// ```
/// MainTabView
/// ├── TabView (native SwiftUI)
/// │   ├── FlicksFeedView      (tab: .flicks)
/// │   ├── HomeFeedView        (tab: .collections)
/// │   ├── CreateFlowWrapper   (tab: .create)
/// │   ├── SearchView          (tab: .search)
/// │   └── CurrentUserProfile  (tab: .profile)
/// └── BottomTabBar (custom overlay)
/// ```
///
/// ## Key Features
/// - **Tab Management**: Custom tab bar with enhanced behaviors
/// - **Upload Coordination**: Global upload progress and retry logic
/// - **Deep Linking**: URL-based navigation to specific content
/// - **Cross-Tab Communication**: Coordinated refreshes and state changes
/// - **Development Tools**: Version tracking and update notifications
///
/// ## Coordinators
/// - ``TabViewCoordinator``: Manages tab selection and navigation paths
/// - ``AppCoordinator``: Handles cross-feature triggers and global state
/// - ``TabViewModel``: Manages upload state and retry logic
///
/// ## Upload Flow Integration
/// The view listens for upload notifications and coordinates:
/// 1. **Upload Progress**: Visual progress indicators
/// 2. **Retry Logic**: Failed upload recovery
/// 3. **State Updates**: Refresh relevant feeds after upload
/// 4. **Error Handling**: User-friendly error messages
///
/// ## Environment Dependencies
/// Requires all major app stores and coordinators:
/// - ``UserStore``, ``CliqueStore``, ``CollectionStore``, ``CollectionImageStore``
/// - ``AppCoordinator`` for global triggers
/// - Toast system for user feedback
///
/// - Important: This view assumes user authentication is complete
/// - Note: Hides native UITabBar in favor of custom implementation
struct MainTabView: View {
    // MARK: - Persistent State
    /// Tracks last seen app version for "What's New" features
    @AppStorage("lastSeenAppVersion") private var lastSeenVersion: String?
    
    // MARK: - Environment
    /// System URL opening capability
    @Environment(\.openURL) private var openURL
    /// Toast notification presentation
    @Environment(\.presentToast) private var presentToast
    /// Global app coordination and triggers
    @Environment(AppCoordinator.self) private var appCoordinator
    
    // MARK: - Data Stores
    /// User data and authentication state
    @Environment(UserStore.self) private var userStore
    /// Clique/group data management
    @Environment(CliqueStore.self) private var cliqueStore
    /// Collection metadata store
    @Environment(CollectionStore.self) private var collectionStore
    /// Individual image data and caching
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    // MARK: - Coordinators and ViewModels
    /// Tab navigation and state coordination
    @State private var tabViewCoordinator = TabViewCoordinator()
    /// Upload flow management and retry logic
    @State private var viewModel = TabViewModel()
    /// Deep link navigation target
    @State var deeplinkTarget: DeepLinkManager.DeeplinkTarget?
    
    // MARK: - UI State
    /// Whether to show "What's New" modal
    @State private var showWhatsNew = false
    /// Whether to show app update alert
    @State private var showUpdateAlert: Bool = false
    /// Whether to show upload progress UI
    @State private var showUploading: Bool = false
    /// Whether an upload is currently in progress
    @State private var isUploading: Bool = false
    
    /// Computed property providing quick access to current user.
    ///
    /// This user is guaranteed to exist at this point in the app flow
    /// because ``AuthService.loadUserData()`` ensures authentication
    /// before transitioning to the main app experience.
    ///
    /// - Returns: The currently authenticated user
    /// - Important: Will crash if called before authentication is complete
    private var user: User {
        userStore.currentUser! // must exist by this point. logic in AuthService.loadUserData()
    }
    
    /// Initializes MainTabView with custom tab bar configuration.
    ///
    /// This initializer configures the view for custom tab bar usage
    /// by hiding the native UITabBar and preparing for overlay-based navigation.
    ///
    /// ## Configuration
    /// - Hides native `UITabBar` globally
    /// - Prepares for custom ``BottomTabBar`` overlay
    /// - Sets up tab appearance for the app
    ///
    /// - Note: Uses global UITabBar appearance which affects the entire app
    init() {
        UITabBar.appearance().isHidden = true // hide the native tab bar
    }
    
    /// The main view body implementing the complete tab-based app experience.
    ///
    /// This view creates a layered interface with:
    /// - Background TabView for main content
    /// - Upload progress overlay when needed
    /// - Custom tab bar overlay with animations
    ///
    /// ## Layout Structure
    /// ```
    /// ZoomContainer
    /// └── ZStack
    ///     ├── TabView (background layer)
    ///     └── VStack (overlay layer)
    ///         ├── UploadProgressView (conditional)
    ///         └── BottomTabBar (custom navigation)
    /// ```
    ///
    /// ## Tab Configuration
    /// Each tab is configured with proper store dependencies:
    /// - **Flicks**: Personal feed with social features
    /// - **Collections**: Curated content and discovery
    /// - **Create**: Photo capture and upload flows
    /// - **Search**: User and content discovery
    /// - **Profile**: Current user management
    ///
    /// ## Upload Integration
    /// The upload system provides:
    /// - Real-time progress tracking
    /// - Error handling and retry logic
    /// - Non-blocking user experience
    /// - Automatic feed refresh after completion
    var body: some View {
        ZoomContainer {
            ZStack(alignment: .bottom) {
                // Main tab content
                TabView(selection: $tabViewCoordinator.activeTab) {
                    FlicksFeedView(collectionStore, collectionImageStore, cliqueStore, userStore)
                        .tag(BottomTab.flicks)
                    
                    HomeFeedView(collectionStore, collectionImageStore, userStore, cliqueStore)
                        .tag(BottomTab.collections)
                    
                    CreateFlowWrapper()
                        .tag(BottomTab.create)
                    
                    SearchView(userStore)
                        .tag(BottomTab.search)
                    
                    CurrentUserProfileView()
                        .tag(BottomTab.profile)
                }
                
                // Overlay UI (upload progress + tab bar)
                VStack(spacing: 8) {
                    // Upload progress indicator
                    if showUploading {
                        UploadProgressView(
                            collectionId: viewModel.collectionId,
                            totalFlicks: viewModel.totalImages,
                            successfulFlicks: viewModel.successfulImages,
                            failedFlicks: viewModel.retryImages?.count ?? 0,
                            showUploading: $showUploading,
                            showNav: !isUploading && !viewModel.collectionId.isEmpty,
                            showRetry: viewModel.uploadFailed,
                            retryAction: {
                                isUploading = true
                                Task {
                                    do {
                                        try await viewModel.retryUploadImages()
                                    } catch {
                                        presentToast(Toasts.somethingWentWrong)
                                    }
                                    isUploading = false
                                }
                            }
                        )
                        .padding(.horizontal, 8)
                    }
                    
                    // Custom tab bar with smooth animations
                    BottomTabBar()
                        .opacity(tabViewCoordinator.showTabBar ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: tabViewCoordinator.showTabBar)
                }
            }
            // Safe area configuration for proper tab bar positioning
            .padding(.bottom, 18)
            .ignoresSafeArea(edges: .bottom)
            
            // failed sheet overlay try. works for swiping down but not tapping out
            //            .overlay {
            //                Rectangle()
            //                    .fill(tabViewCoordinator.overlayColor)
            //                    .ignoresSafeArea()
            //                    .animation(.easeInOut, value: tabViewCoordinator.overlayColor)
            //            }
        }
        .onReceive(of: .uploadImagesToCollection) { notification in
            guard let collection = notification.userInfo?["collection"] as? ClCollection,
                  let makingNew = notification.userInfo?["makingNew"] as? Bool,
                  let photoDatePairs = notification.userInfo?["photoDatePairs"] as? [Components.Schemas.PhotoVideoDate],
                  let variants  = notification.userInfo?["variants"] as? [PreparedImageVariant],
                  let livePhotoAssets = notification.userInfo?["livePhotoAssets"] as? [(assetId: String, asset: PHAsset)?],
                  let transcodedVideoUrls = notification.userInfo?["transcodedVideoUrls"] as? [URL?],
                  let allAssetIdentifiers = notification.userInfo?["allAssetIdentifiers"] as? [String?]
            else { return }

            isUploading = true
            showUploading = true

            Task {
                do {
                    try await viewModel.uploadToCollection(
                        makingNew: makingNew,
                        photoDatePairs: photoDatePairs,
                        preparedImages: variants,
                        livePhotoAssets: livePhotoAssets,
                        transcodedVideoUrls: transcodedVideoUrls,
                        allAssetIdentifiers: allAssetIdentifiers,
                        collection: collection,
                        collectionStore,
                        collectionImageStore
                    )
                    
                    trigger(.refreshHomeFeed)
                    trigger(.refreshUserCollections)
                    tabViewCoordinator.triggerRefreshFlicksFeed.toggle()
                } catch {
                    presentToast(Toasts.somethingWentWrong)
                }

                isUploading = false
            }
        }
        .environment(tabViewCoordinator)
        //        .statusBarHidden(tabViewCoordinator.hideStatusBar)
        .ignoresSafeArea(.keyboard) // prevent keyboard from moving tab bar up
        //        .onOpenURL { url in
        //            let deeplinkManager = DeepLinkManager()
        //            let deeplink = deeplinkManager.manage(url)
        //            switch deeplink {
        //            case .home:
        //                tabViewCoordinator.appendToPath(value: Clique.MOCK_CLIQUES[0])
        //            case .details(let queryInfo):
        //                print(queryInfo)
        //            }
        //        }
//        .onReceive(NotificationCenter.default.publisher(for: .didTapNotification)) { _ in
//            tabViewCoordinator.navigate(to: "CurrentUser")
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                appCoordinator.triggerOpenInboxSheet.toggle()
//            }
//        }
        .onChange(of: appCoordinator.shouldOpenNotificationCenter, initial: true) { oldValue, newValue in
            guard newValue else { return }
            
            tabViewCoordinator.profileNavigationPath = NavigationPath()
            tabViewCoordinator.activeTab = .profile
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tabViewCoordinator.navigate(to: "NotificationsCenter")
                appCoordinator.shouldOpenNotificationCenter = false
            }
        }
        .onChange(of: showWhatsNew) { oldValue, newValue in
            guard oldValue == true, newValue == false else { return }
            lastSeenVersion = AppConfig.currentVersion
        }
        .whatsNewOverlay(showWhatsNew: $showWhatsNew)
        .onAppear {
            checkNotifications()
            
            // Also trigger inbox notification check for clique invites and follow requests
            trigger(.checkInboxNotifications)
            
            if userStore.currentUserId != "cad46bda-7c82-4684-a95d-bed84f88dcc1" { // test 1 (apple reviewer login)
                Task {
                    showUpdateAlert = await AppService.isUpdateAvailable()
                }
            }
            
            if lastSeenVersion != AppConfig.currentVersion {
                showWhatsNew = true
            }
            
            AppService.checkAndRegisterPushNotificationsIfNeeded(userStore: userStore)
        }
        .alert("New update!", isPresented: $showUpdateAlert) {
            Button("Maybe Later") {
                showUpdateAlert = false
            }
            
            Button("Update") {
                guard let url = URL(string: "https://apps.apple.com/us/app/clique-group-social/id6742713460") else { return }
                
                openURL(url)
            }
        } message: {
            Text("Good news! A new version of Clique is available.")
        }
        .onReceive(of: .checkNotifications) { _ in
            checkNotifications()
            // Also check inbox notifications
            trigger(.checkInboxNotifications)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveDeviceToken)) { notification in
            Task {
                do {
                    try saveToken(notification)
                } catch {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
        .fullScreenCover(isPresented: $tabViewCoordinator.showCliqueCreator) {
            CreateCliqueView()
//            CliqueCreatorFlow()
                .environment(tabViewCoordinator)
        }
    }
    
    private func checkNotifications() {
        Task {
            do {
                let hasGeneralNoti = try await NotificationService.getNotificationStatus(.init())
                let hasInviteNoti = try await NotificationService.getNotificationInviteStatus(.init())
                let hasAnyNoti = hasGeneralNoti || hasInviteNoti
                
                if !hasAnyNoti {
                    DispatchQueue.main.async {
                        UNUserNotificationCenter.current().setBadgeCount(0)
                    }
                }
                tabViewCoordinator.hasNotification = hasAnyNoti
            } catch {
                tabViewCoordinator.hasNotification = false
            }
        }
    }
}

#Preview {
    MainTabView()
}
