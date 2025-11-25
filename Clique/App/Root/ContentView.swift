//
//  ContentView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/18/24.
//

import SwiftUI

/// Root view that orchestrates the app's main navigation flow.
///
/// This view serves as the primary router for the entire application,
/// determining which major app experience to display based on the user's
/// authentication state and app initialization progress.
///
/// ## App State Flow
/// ```
/// ContentView
/// ├── .splash     → Loading/initialization screen
/// ├── .auth       → Authentication flow (login/signup)
/// └── .main       → Authenticated app experience
/// ```
///
/// ## State Management
/// The view relies on ``AuthService`` to determine the current app state:
/// - **Splash**: Initial app load, checking existing authentication
/// - **Auth**: User needs to sign in or create account
/// - **Main**: User is authenticated and can access full app
///
/// ## Architecture Role
/// This view acts as the bridge between system-level app setup (handled by
/// ``CliqueApp``) and feature-level navigation (handled by ``MainTabView``).
/// It ensures proper initialization order and smooth transitions.
///
/// ## Integration
/// - Created by ``CliqueApp`` with injected ``UserStore``
/// - Manages ``AuthService`` lifecycle and state
/// - Provides environment context for child views
///
/// ## Usage Example
/// ```swift
/// // In CliqueApp.swift
/// ContentView(userStore)
///     .environment(appCoordinator)
///     .environment(userStore)
///     // ... other environment objects
/// ```
///
/// - Important: This view must receive a valid ``UserStore`` instance
/// - Note: State transitions are automatic based on authentication status
struct ContentView: View {
    /// Safe area insets for proper layout in splash screen
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.presentToast) private var presentToast
   
    /// User data store for authentication state management
    @Environment(UserStore.self) private var userStore
  
    /// Authentication service managing app state and user session
    @State private var authService: AuthService
    
    @State private var isAppBricked: Bool = false

    /// Counter that increments during app initialization to force SwiftUI view updates.
    /// This is a workaround for a SwiftUI bug where @Observable property changes on AuthService
    /// are not properly observed when the app runs without the Xcode debugger attached.
    /// By updating this @State variable and referencing it in the view, we force SwiftUI
    /// to re-evaluate the view body and notice the authService.appViewType change.
    @State private var loadingPhase: Int = 0
    
    /// Initializes ContentView with required user store dependency.
    ///
    /// The user store is passed explicitly to ensure the AuthService
    /// has access to user data and can properly manage authentication state.
    ///
    /// - Parameter userStore: The user store instance from ``CliqueApp``
    ///
    /// ## Initialization Flow
    /// 1. **Store Injection**: Receives UserStore from parent
    /// 2. **AuthService Creation**: Creates AuthService with store reference
    /// 3. **State Setup**: Prepares for authentication state observation
    ///
    /// - Note: The AuthService will begin checking authentication status immediately
    init(_ userStore: UserStore) {
        self.authService = .init(userStore)
    }
    
    /// The main view body implementing app state routing.
    ///
    /// This view switches between different app experiences based on the
    /// current authentication and initialization state. Each state provides
    /// a complete, self-contained user experience.
    ///
    /// ## State Descriptions
    /// - **Splash**: Minimal loading screen while checking authentication
    /// - **Auth**: Complete authentication flow with login/signup options
    /// - **Main**: Full authenticated app with tabs, feeds, and features
    ///
    /// ## View Transitions
    /// Transitions between states are automatic and based on:
    /// - Authentication token validation
    /// - User data loading completion
    /// - Network connectivity status
    ///
    /// ## Environment Propagation
    /// Each major view receives the AuthService for:
    /// - Authentication state monitoring
    /// - User session management
    /// - Logout functionality
    var body: some View {
        Group {
            if isAppBricked {
                Text("Servers are currently under maintenance. Try again later.")
            } else {
                switch authService.appViewType {
                case .splash:
                    // Minimal loading screen during app initialization
                    VStack(spacing: 8) {
                        Image("splash")
                            .resizable()
                            .scaledToFit()
                            .frame(160)
                    }
                    .ignoresSafeArea()
                    .padding(.bottom, safeAreaInsets.bottom - 8)
                    .infiniteFrame()
                    .background(Color.theme.white)
                    // Reference loadingPhase to ensure SwiftUI re-renders when it changes (see loadingPhase docs)
                    .id(loadingPhase)
                    
                case .auth:
                    // Complete authentication experience
                    AuthSplashView()
                        .environment(authService)
                    // Future: Push notification registration
                    // .onAppear {
                    //     AppService.checkAndRegisterPushNotificationsIfNeeded(userStore: userStore)
                    // }
                    
                case .main:
                    // Full authenticated app experience
                    MainTabView()
                        .environment(authService)
                        .onReceive(of: .toast404) { _ in
                            presentToast(Toasts.somethingWentWrong)
                        }
                }
            }
        }
        .id(authService.appViewType) // iOS 26.1 fix: Force view recreation on state change because TabView causes the application to hang with repeated AttributeGraph cycle detected messages
        .onAppear {
            // Begin authentication state evaluation
            Task {
                loadingPhase = 1
                isAppBricked = await AppService.isAppBricked()
                loadingPhase = 2
                await authService.loadUserData()
                loadingPhase = 3
            }
        }
    }
}
