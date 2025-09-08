//
//  CliqueApp.swift
//  Clique
//
//  Created by Rod Tavangar on 6/9/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore
import UserNotifications
import Toasts
import BackgroundTasks
import TipKit
import Mixpanel

/// The main application entry point for Clique iOS app.
///
/// This struct orchestrates the entire app initialization and lifecycle management,
/// handling everything from Firebase configuration to background task scheduling.
/// It serves as the foundation for the app's architecture and coordinates all
/// major system integrations.
///
/// ## Key Responsibilities
/// - **Firebase Integration**: Configures authentication, messaging, and analytics
/// - **Background Tasks**: Manages feed refresh and data synchronization
/// - **Environment Setup**: Injects all observable stores throughout the app
/// - **Push Notifications**: Handles registration and routing
/// - **App Lifecycle**: Manages foreground/background transitions
/// - **Third-party Services**: Initializes Kingfisher, TipKit, and Mixpanel
///
/// ## Architecture Overview
/// The app follows a centralized store pattern with environment injection:
/// ```
/// CliqueApp
/// ├── AppCoordinator (global state)
/// ├── Observable Stores (UserStore, CliqueStore, etc.)
/// └── ContentView (root routing)
///     └── MainTabView (authenticated experience)
/// ```
///
/// ## Environment Objects
/// All major stores are created here and injected as environment objects:
/// - ``UserStore``: User data and authentication state
/// - ``CliqueStore``: Group/clique information
/// - ``CollectionStore``: Photo collection metadata
/// - ``CollectionImageStore``: Individual image management
/// - ``CommentStore``: Comments and social interactions
/// - ``AppCoordinator``: Global triggers and cross-feature coordination
///
/// ## Usage Example
/// ```swift
/// // App automatically initializes all systems
/// // Access stores anywhere in the app:
/// @Environment(UserStore.self) private var userStore
/// @Environment(AppCoordinator.self) private var appCoordinator
/// ```
///
/// - Important: This is the single source of truth for app-wide configuration
/// - Note: Background tasks require special entitlements in Info.plist
@main
struct CliqueApp: App {
    /// Firebase and system delegate for handling app lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    /// User's preferred theme setting (light/dark/system)
    @AppStorage("userTheme") private var userTheme: Theme = .systemDefault
    
    /// Global coordinator for cross-feature triggers and state
    @State private var appCoordinator = AppCoordinator()
    
    // MARK: - Observable Stores
    /// Central user data store
    @State private var userStore = UserStore()
    /// Clique/group data management
    @State private var cliqueStore = CliqueStore()
    /// Photo collection metadata store
    @State private var collectionStore = CollectionStore()
    /// Individual image data and caching
    @State private var collectionImageStore = CollectionImageStore()
    /// Comments and social interaction data
    @State private var commentStore = CommentStore()
    
    /// Initializes the app with all required system configurations.
    ///
    /// This initializer sets up critical app infrastructure before the UI loads:
    /// - Registers background task identifiers with the system
    /// - Configures Kingfisher for optimal image caching
    /// - Prepares development tools in debug builds
    ///
    /// - Note: Firebase configuration happens in AppDelegate for proper timing
    init() {
        // Development tools (commented out for production)
        // loadRocketSimConnect()
        
        registerBackgroundTasks()
        KingfisherConfig.configure()
    }
    
    /// The main scene containing the app's UI hierarchy.
    ///
    /// This scene sets up the complete environment and handles system-level events:
    /// - Injects all observable stores as environment objects
    /// - Configures toast notifications and theming
    /// - Handles app lifecycle transitions (foreground/background)
    /// - Sets up TipKit for user onboarding
    /// - Manages push notification routing
    ///
    /// ## Environment Injection Pattern
    /// All stores are injected here and available throughout the app hierarchy:
    /// ```swift
    /// ContentView
    ///   .environment(appCoordinator)    // Global coordination
    ///   .environment(userStore)         // User data
    ///   .environment(cliqueStore)       // Clique data
    ///   // ... other stores
    /// ```
    var body: some Scene {
        WindowGroup {
            ContentView(userStore)
                .environment(appCoordinator)
                .installToast(position: appCoordinator.toastPosition)
                .preferredColorScheme(userTheme.colorScheme)
                .environment(userStore)
                .environment(cliqueStore)
                .environment(collectionStore)
                .environment(collectionImageStore)
                .environment(commentStore)
                .onAppear {
                    handleForegroundEntry()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    handleForegroundEntry()
                }
                .task {
                    // TipKit configuration for user onboarding
                    // try? Tips.resetDatastore() // uncomment to force show tips
                    try? Tips.configure([
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .onReceive(of: .didTapNotification) { _ in
                    appCoordinator.shouldOpenNotificationCenter = true
                }
        }
    }
    
    /// Handles app entering foreground with comprehensive data refresh.
    ///
    /// This method coordinates a full app refresh when users return to the app,
    /// ensuring they see the latest content and notifications. It triggers
    /// updates across all major data sources.
    ///
    /// ## Refresh Strategy
    /// - **Notifications**: Check for new notifications and update badges
    /// - **Feeds**: Refresh home feed and clique hub for latest content
    /// - **Active Cliques**: Update all currently viewed clique feeds
    /// - **Background Data**: Sync any data that may have changed
    ///
    /// ## Usage
    /// Called automatically on:
    /// - App launch (`onAppear`)
    /// - Returning from background (`willEnterForegroundNotification`)
    ///
    /// - Note: Uses ``AppCoordinator`` triggers to coordinate updates across features
    private func handleForegroundEntry() {
        trigger(.checkNotifications)
        
        trigger(.refreshHomeFeed)
        trigger(.refreshCliqueHubFeed)
        
        // Refresh all active Clique Profile Feeds
        for cliqueID in appCoordinator.activeCliqueFeeds {
            trigger(.refreshCliqueFeed, object: cliqueID)
        }
    }
    
    /// Registers background task handlers with the system.
    ///
    /// This method sets up background task capabilities that allow the app
    /// to refresh content even when not actively in use, providing users
    /// with up-to-date content when they return.
    ///
    /// ## Background Task: Feed Refresh
    /// - **Identifier**: `com.clique.feed.refresh`
    /// - **Purpose**: Update feeds and sync critical data
    /// - **Frequency**: Every 15 minutes (system permitting)
    /// - **Duration**: Limited by system (typically 30 seconds)
    ///
    /// ## Requirements
    /// - Background App Refresh capability in Info.plist
    /// - Background Modes entitlement
    /// - User must have Background App Refresh enabled
    ///
    /// - Important: Background execution is not guaranteed and depends on user behavior
    /// - Note: Called during app initialization before UI appears
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.clique.feed.refresh", using: nil) { task in
            self.handleFeedRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    /// Schedules the next background refresh task with the system.
    ///
    /// This static method requests permission to run a background refresh task
    /// in the future. The system may or may not honor this request based on
    /// user behavior patterns and device conditions.
    ///
    /// ## Scheduling Strategy
    /// - **Interval**: 15 minutes minimum between refreshes
    /// - **Retry Logic**: Attempts to reschedule if initial request fails
    /// - **Error Handling**: Graceful degradation with logging
    ///
    /// ## System Behavior
    /// The system considers:
    /// - User app usage patterns
    /// - Device battery level and charging state
    /// - Background App Refresh settings
    /// - Overall system load
    ///
    /// ## Usage
    /// ```swift
    /// // Called automatically after each background refresh
    /// CliqueApp.scheduleBackgroundFeedRefresh()
    /// 
    /// // Called when app enters background
    /// applicationDidEnterBackground(_:)
    /// ```
    ///
    /// - Important: No guarantee the task will execute; plan for app-initiated refresh
    static func scheduleBackgroundFeedRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.clique.feed.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
            
            // Retry mechanism for transient failures
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                do {
                    try BGTaskScheduler.shared.submit(request)
                } catch {
                    print("Retry failed: Could not schedule app refresh.")
                }
            }
        }
    }
    
    /// Executes background feed refresh with proper task lifecycle management.
    ///
    /// This method runs when the system grants background execution time,
    /// performing essential data synchronization to keep content fresh.
    /// It has limited time to execute (typically 30 seconds).
    ///
    /// ## Background Refresh Process
    /// 1. **Schedule Next**: Immediately request next background refresh
    /// 2. **Refresh Data**: Update critical feeds and content
    /// 3. **Complete Task**: Signal success/failure to the system
    /// 4. **Handle Expiration**: Graceful cleanup if time runs out
    ///
    /// ## Performance Considerations
    /// - **Time Limited**: Must complete quickly or face termination
    /// - **Network Dependent**: May fail on poor connections
    /// - **Battery Aware**: Should minimize resource usage
    ///
    /// ## Data Priority
    /// Currently refreshes:
    /// - Home feed (essential user content)
    /// - Future: Clique hub and other critical feeds
    ///
    /// - Parameter task: The system-provided background task to manage
    /// - Important: Always call `setTaskCompleted` to maintain background privileges
    private func handleFeedRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh immediately to maintain cadence
        CliqueApp.scheduleBackgroundFeedRefresh()
        
//        Task {
//            await refreshFeed() // Home Feed Refresh
//            // await refreshCliqueHubFeed() // Future: Clique Hub Feed Refresh
//            task.setTaskCompleted(success: true)
//        }
        
        trigger(.refreshHomeFeed)
        task.setTaskCompleted(success: true)
        
        // Handle system forcing task completion
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }
    
    /// Loads RocketSim development tools in debug builds.
    ///
    /// RocketSim is a development tool that enhances the iOS Simulator
    /// with additional debugging capabilities, device frame recording,
    /// and other productivity features.
    ///
    /// ## Features When Loaded
    /// - Enhanced simulator debugging
    /// - Screen recording capabilities
    /// - Network request monitoring
    /// - Performance insights
    ///
    /// ## Usage
    /// ```swift
    /// // Called automatically in debug builds during app init
    /// loadRocketSimConnect()
    /// ```
    ///
    /// - Note: Only loads in DEBUG builds, has no effect in production
    /// - Note: Requires RocketSim app to be installed at the expected path
    private func loadRocketSimConnect() {
        #if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
}

/// Application delegate handling system-level app events and integrations.
///
/// This delegate manages critical app integrations that require UIKit-level access:
/// Firebase configuration, push notifications, authentication, and analytics.
/// It bridges between the system and SwiftUI app architecture.
///
/// ## Key Integrations
/// - **Firebase**: Core configuration and authentication
/// - **Push Notifications**: Registration, routing, and handling
/// - **Mixpanel**: Analytics initialization and configuration
/// - **Background Tasks**: Scheduling and lifecycle management
///
/// ## Notification Flow
/// ```
/// System Notification → AppDelegate → NotificationCenter → SwiftUI Views
/// ```
///
/// ## Usage
/// Automatically used via `@UIApplicationDelegateAdaptor` in ``CliqueApp``.
/// No direct instantiation required.
///
/// - Important: Handles security-critical functions like authentication tokens
/// - Note: Bridges UIKit delegate pattern with SwiftUI reactive architecture
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        FirebaseApp.configure()
        
        // ✅ Set notification center delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self

        // Initialize Mixpanel
        if let token = Bundle.main.object(forInfoDictionaryKey: "MixpanelToken") as? String {
            Mixpanel.initialize(token: token, trackAutomaticEvents: false)
        } else {
            print("❗️Error: Mixpanel token not found in Info.plist")
        }
        
        return true
    }
    
    // ✅ Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 👇 This makes sure banners/sounds show even if app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    // ✅ Called when the user taps the notification (background, foreground, or terminated)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .didTapNotification, object: nil)
        }
        completionHandler()
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
#if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox) // Xcode installs
#else
        Auth.auth().setAPNSToken(deviceToken, type: .prod) // App Store installs
#endif
        
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
//        print(token)
        
        // TODO: uncomment. currently forcing token update for everyone so people without get it
        if token != AppService.userToken || !AppService.hasRegisteredForPush {
            // ✅ Post device token for backend update
            NotificationCenter.default.post(name: .didReceiveDeviceToken, object: nil, userInfo: ["token": token])
        }
        
        AppService.userToken = token
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Handle Incoming Notifications (Firebase/Auth-specific)
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
        } else {
            // Handle other notifications here if needed
//            completionHandler(.noData)
        }
    }
    
    // MARK: - Handle Auth URL (for sign-in, password reset, etc.)
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        // Handle other URLs if needed
        return false
    }
    
    // MARK: - Handle Scene-based URL (optional, if using scenes)
    func scene(_ scene: UIScene,
               openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            let url = urlContext.url
            _ = Auth.auth().canHandle(url)
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        CliqueApp.scheduleBackgroundFeedRefresh()
    }
}
