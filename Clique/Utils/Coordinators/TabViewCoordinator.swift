//
//  TabBarCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 10/23/24.
//

import SwiftUI
import SwiftUINavigationTransitions

/// Defines the entry point for the photo creation flow.
///
/// The create flow can be initiated from different sources, affecting
/// the initial screen presented to the user.
enum CreateFlowMode {
    /// Start with camera interface for taking new photos
    case camera
    /// Start with photo library for selecting existing photos
    case library
}

/// Central coordinator managing navigation and state across all main app tabs.
///
/// This coordinator implements the core navigation architecture for the app,
/// managing independent navigation paths for each tab while providing
/// centralized control over tab selection and cross-tab navigation.
///
/// ## Architecture Overview
/// - **Type-safe navigation**: Uses SwiftUI's NavigationPath with value-based routing
/// - **Independent tab stacks**: Each tab maintains its own navigation history
/// - **Smart tab behavior**: Tapping active tab triggers contextual actions
/// - **Create flow management**: Special handling for photo creation workflows
///
/// ## Navigation Patterns
/// ```swift
/// // Navigate within current tab
/// coordinator.navigate(to: user)
/// 
/// // Switch tabs
/// coordinator.selectTab(.collections)
/// 
/// // Start create flow
/// coordinator.startCreateFlow(for: clique)
/// ```
///
/// ## Tab Behavior
/// When user taps the currently active tab:
/// - **Flicks**: Refresh feed or pop navigation stack
/// - **Collections**: Scroll to top or pop navigation stack
/// - **Search**: Focus search field or pop navigation stack
/// - **Profile**: Pop navigation stack only
/// - **Create**: No special behavior (shows menu)
///
/// - Important: Always access from @MainActor context for thread safety
/// - Note: Designed to work with ``NavigationDestinationsModifier`` for global routes
@Observable @MainActor final class TabViewCoordinator {
    // MARK: - UI Triggers

    /// Triggers scroll-to-top animation for collections feed
    var triggerScrollToTopOfFeed: Bool = false
    /// Triggers refresh of the flicks feed
    var triggerRefreshFlicksFeed: Bool = false
    /// Triggers scroll-to-top for user's collections view
    var triggerScrollToTopOfMyCollections: Bool = false
    /// Triggers focus on search text field
    var triggerFocusSearch: Bool = false
    /// Triggers scroll-to-top for flicks grid view
    var triggerScrollToTopOfFlicksGrid: Bool = false
    
    // MARK: - Status Flags

    /// Whether the flicks feed is currently refreshing
    var isFlicksFeedRefreshing: Bool = false
    /// Whether to show the clique creation interface
    var showCliqueCreator: Bool = false
    /// Whether to focus the comment keyboard input
    var focusCommentKeyboard: Bool = false
    /// Whether flicks feed is showing grid view (true) or carousel view (false)
    var flicksShowGrid: Bool = true
    
    // MARK: - Create Flow State
    
    /// Current mode for the create flow (camera or library)
    var createFlowMode: CreateFlowMode = .camera
    
    // MARK: - Tab Bar State
    
    /// Whether the tab bar should be visible
    var showTabBar: Bool = true
    /// Currently selected tab
    var activeTab: BottomTab = .flicks
    /// Previously selected tab (for restoration)
    var previousTab: BottomTab = .flicks
    /// Whether there are unread notifications
    var hasNotification: Bool = false
    
    // MARK: - Visual State
    
    /// Overlay color for visual effects
    var overlayColor: Color = .clear
    
    // MARK: - Navigation Transitions
    
    /// Pan gesture interactivity for navigation transitions
    var pan: AnyNavigationTransition.Interactivity = .pan
    /// Animation configuration for navigation transitions
    var animation: AnyNavigationTransition = Constants.mainTransition
    /// Progress of dismiss drag gesture (0.0 to 1.0)
    var dismissDragProgress: CGFloat = 0
    
    // MARK: - Create Flow Context
    
    /// Initial clique context when starting create flow
    var createFlowInitialClique: Clique?
    /// Initial collection context when starting create flow
    var createFlowInitialCollection: ClCollection?
    /// Whether to open photo library immediately in create flow
    var shouldOpenLibrary: Bool = false
    
    // MARK: - Navigation Paths
    
    /// Navigation path for the flicks/feed tab
    var flicksNavigationPath = NavigationPath()
    /// Navigation path for the collections tab
    var collectionsNavigationPath = NavigationPath()
    /// Navigation path for the search tab
    var searchNavigationPath = NavigationPath()
    /// Navigation path for the profile tab
    var profileNavigationPath = NavigationPath()
    /// Navigation path for the create flow
    var createNavigationPath = NavigationPath()
    
    /// Navigates to a destination within the currently active tab.
    ///
    /// This method appends the given value to the appropriate navigation path
    /// based on the currently active tab. The value is typically a domain model
    /// (User, Clique, Collection) or string identifier.
    ///
    /// - Parameter value: The navigation destination (must be Hashable)
    ///
    /// ## Example Usage
    /// ```swift
    /// // Navigate to a user profile
    /// coordinator.navigate(to: user)
    /// 
    /// // Navigate to settings
    /// coordinator.navigate(to: "UserSettings")
    /// ```
    ///
    /// - Note: Create tab has no navigation stack, so navigation is ignored
    func navigate(to value: any Hashable) {
        switch activeTab {
        case .flicks:
            flicksNavigationPath.append(value)
        case .collections:
            collectionsNavigationPath.append(value)
        case .search:
            searchNavigationPath.append(value)
        case .create:
            return // no overarching navstack for add tab
        case .profile:
            profileNavigationPath.append(value)
        }
    }
    
    /// Clears the navigation path for the currently active tab.
    ///
    /// This resets the navigation stack to the root view for the active tab,
    /// effectively "popping" all pushed views.
    ///
    /// ## When to Use
    /// - User logs out (clear all navigation)
    /// - Tab switching with reset behavior
    /// - Error recovery scenarios
    ///
    /// - Warning: This immediately dismisses all views in the navigation stack
    func clearPath() {
        switch activeTab {
        case .flicks:
            flicksNavigationPath = NavigationPath()
        case .collections:
            collectionsNavigationPath = NavigationPath()
        case .search:
            searchNavigationPath = NavigationPath()
        case .create:
            createNavigationPath = NavigationPath()
        case .profile:
            profileNavigationPath = NavigationPath()
        }
    }
    
    /// Handles tab selection with smart behavior for repeated taps.
    ///
    /// This method implements the core tab switching logic with contextual
    /// behavior when users tap the currently active tab.
    ///
    /// ## Behavior by Tab
    /// **Same tab tapped:**
    /// - **Flicks**: Scroll to top (if grid view at root), switch to grid (if carousel at root), or pop navigation
    /// - **Collections**: Scroll to top (if at root) or pop navigation
    /// - **Search**: Focus search field (if at root) or pop navigation
    /// - **Profile**: Pop navigation only
    /// - **Create**: No special behavior
    ///
    /// **Different tab tapped:**
    /// - Switch to new tab
    /// - Hide tab bar for create flow
    /// - Update previous tab reference
    ///
    /// - Parameter tab: The tab to select
    func selectTab(_ tab: BottomTab) {
        if tab == activeTab {
            switch tab {
            case .flicks:
                if flicksNavigationPath.isEmpty {
                    if flicksShowGrid {
                        // In grid view: scroll to top
                        triggerScrollToTopOfFlicksGrid.toggle()
                    } else {
                        // In carousel view: switch to grid view
                        flicksShowGrid = true
                    }
                } else {
                    flicksNavigationPath.removeLast()
                }
            case .collections:
                if collectionsNavigationPath.isEmpty {
                    trigger(.scrollToTopOfFeed)
                } else {
                    collectionsNavigationPath.removeLast()
                }
            case .create:
                return // no overarching navstack for add tab
            case .search:
                if searchNavigationPath.isEmpty {
                    trigger(.focusSearchTab)
                } else {
                    searchNavigationPath.removeLast()
                }
            case .profile:
                guard !profileNavigationPath.isEmpty else { return }
                profileNavigationPath.removeLast()
//            }
//            case .collections:
//                if collectionsNavigationPath.isEmpty  {
//                    triggerScrollToTopOfMyCollections.toggle()
//                } else {
//                    collectionsNavigationPath.removeLast()
//                }
            // trigger dismiss and wait to switch back so view is destroyed
//            tabCoordinator.sameTabTapped = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                tabCoordinator.sameTabTapped = false
            }
        } else {
            if tab == .create {
                showTabBar = false
            }
            previousTab = activeTab
            activeTab = tab
        }
    }
    
    /// Initiates the photo creation flow for a specific clique.
    ///
    /// This method switches to the create tab and sets up the context
    /// for creating content within the specified clique.
    ///
    /// - Parameter clique: The clique context for the create flow
    ///
    /// ## Usage
    /// ```swift
    /// // Start create flow from clique profile
    /// coordinator.startCreateFlow(for: selectedClique)
    /// ```
    func startCreateFlow(for clique: Clique) {
        selectTab(.create)
        createFlowInitialClique = clique
    }
    
    /// Initiates the photo creation flow for a specific collection.
    ///
    /// This method switches to the create tab and sets up the context
    /// for adding photos to the specified collection.
    ///
    /// - Parameters:
    ///   - collection: The collection context for the create flow
    ///   - shouldOpenLibrary: Whether to immediately open the photo library
    ///
    /// ## Usage
    /// ```swift
    /// // Add photos to existing collection
    /// coordinator.startCreateFlow(for: collection, shouldOpenLibrary: true)
    /// ```
    func startCreateFlow(for collection: ClCollection, shouldOpenLibrary: Bool = false) {
        selectTab(.create)
        self.shouldOpenLibrary = shouldOpenLibrary
        createFlowInitialCollection = collection
    }
}
