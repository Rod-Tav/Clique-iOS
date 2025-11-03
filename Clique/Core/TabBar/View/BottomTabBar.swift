//
//  BottomTabBar.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

/// Custom bottom tab bar implementation with enhanced user interaction patterns.
///
/// This component replaces the native UITabBar with a custom SwiftUI implementation
/// that provides advanced interaction patterns, visual customization, and integration
/// with the app's design system and navigation architecture.
///
/// ## Key Features
/// - **Enhanced Gestures**: Tap and long-press behaviors for each tab
/// - **Special Create Tab**: Menu-driven creation flow (Camera/Library/Create Clique)
/// - **Visual Feedback**: Loading states, notification badges, and selection indicators
/// - **Theme Integration**: Semantic colors that adapt to light/dark mode
/// - **Smart Behaviors**: Context-aware actions based on current tab state
///
/// ## Interaction Patterns
/// ### Standard Tabs (Flicks, Collections, Search, Profile)
/// - **Tap**: Switch to tab or trigger special actions if already active
/// - **Long Press**: Clear navigation stack or switch to tab with haptic feedback
///
/// ### Create Tab
/// - **Tap**: Shows menu with Camera, Library, and Create Clique options
/// - **Special Styling**: Distinct pink color to emphasize creation actions
///
/// ### Profile Tab
/// - **Visual**: Shows user's profile picture instead of icon
/// - **Notifications**: Red badge indicator for unread notifications
/// - **Border**: Selection ring around profile picture
///
/// ## Integration with TabViewCoordinator
/// This view works closely with ``TabViewCoordinator`` to:
/// - Observe current tab selection
/// - Trigger tab switching and navigation clearing
/// - Manage creation flow modes and states
/// - Handle notification states and refresh indicators
///
/// ## Usage
/// ```swift
/// // Typically used as overlay in MainTabView
/// BottomTabBar()
///     .opacity(tabViewCoordinator.showTabBar ? 1 : 0)
///     .animation(.easeInOut(duration: 0.2), value: tabViewCoordinator.showTabBar)
/// ```
///
/// - Important: Requires ``TabViewCoordinator`` and ``UserStore`` in environment
/// - Note: Uses semantic colors that automatically adapt to theme changes
struct BottomTabBar: View {
    /// Safe area insets for proper layout calculations
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    /// User store for profile picture and notification state
    @Environment(UserStore.self) private var userStore
    /// Tab coordination for navigation and state management
    @Environment(TabViewCoordinator.self) private var tabCoordinator
    
    /// Track which tab is being pressed for animation
    @State private var pressedTab: BottomTab? = nil
    
    /// Computed property for quick access to currently active tab
    private var activeTab: BottomTab {
        tabCoordinator.activeTab
    }
    
    /// The main tab bar view with custom styling and interaction handling.
    ///
    /// This view creates a horizontally laid out tab bar with:
    /// - Evenly distributed tab items
    /// - Special handling for the create tab
    /// - Rounded top corners for modern appearance
    /// - Subtle shadow for depth
    ///
    /// ## Layout Strategy
    /// - **Equal Distribution**: Each tab gets equal horizontal space
    /// - **Infinite Frame**: Tabs expand to fill available space
    /// - **Content Shape**: Full rectangular hit areas for better touch targets
    /// - **Background Styling**: Rounded corners and shadow for visual depth
    ///
    /// ## Gesture Handling
    /// - **Tap Gestures**: Primary navigation action
    /// - **Long Press**: Advanced navigation (clear stack or switch)
    /// - **Create Tab**: Special menu behavior instead of direct navigation
    var body: some View {
        HStack(spacing: 0) {
            ForEach(BottomTab.allCases) { tab in
                if tab == BottomTab.create {
                    // Create tab with menu for entire VStack
                    Menu {
                        Button {
                            tabCoordinator.createFlowMode = .camera
                            tabCoordinator.selectTab(.create)
                        } label: {
                            Text("Camera")
                            Image("camera")
                                .color(.theme.iconPrimary)
                        }
                        
                        Button {
                            tabCoordinator.createFlowMode = .library
                            tabCoordinator.selectTab(.create)
                            trigger(.openLibrary)
                        } label: {
                            Text("Library")
                            Image("images-posts")
                                .color(.theme.iconPrimary)
                        }
                        
                        Button {
                            tabCoordinator.showCliqueCreator = true
                        } label: {
                            Text("Create Clique")
                            Image("3-user")
                                .color(.theme.iconPrimary)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            TabItem(tab: tab)
                            
                            Text(tab.title)
                                .font(.caption2)
                                .fontWeight(.light)
                                .textPrimary()
                        }
                        .infiniteFrame()
                        .contentShape(.rect)
                    }
                } else {
                    // Regular tabs
                    VStack(spacing: 6) {
                        TabItem(tab: tab)
                            .buttonStyle(.noHighlight)
                        
                        Text(tab.title)
                            .font(.caption2)
                            .fontWeight(.light)
                            .textPrimary()
                    }
                    .scaleEffect(pressedTab == tab ? 0.85 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressedTab)
                    .infiniteFrame()
                    .contentShape(.rect)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if pressedTab != tab {
                                    pressedTab = tab
                                }
                            }
                            .onEnded { _ in
                                pressedTab = nil
                                tabCoordinator.selectTab(tab)
                            }
                    )
                    .onLongPressGesture {
                        haptics(.light)
                        if tab == activeTab {
                            // Clear navigation stack for current tab
                            tabCoordinator.clearPath()
                        } else {
                            // Switch to different tab
                            tabCoordinator.selectTab(tab)
                        }
                    }
                }
            }
        }
        .maxWidth(.leading)
        .background {
            // Modern rounded background with theme support
            Color.theme.surfacesBackgroundPrimary
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                .ignoresSafeArea()
        }
        .frame(height: Constants.bottomTabBarHeight)
        .shadow(color: .theme.navbarShadow, radius: 5, x: 0, y: -3)
    }
    
    /// Individual tab bar item with context-aware styling and content.
    ///
    /// This view builder creates different tab representations based on the tab type
    /// and current app state. It handles special cases like profile pictures,
    /// loading states, and notification badges.
    ///
    /// ## Tab Type Handling
    /// - **Profile Tab**: Shows user's profile picture with selection ring
    /// - **Standard Tabs**: Shows themed icons with selection states
    /// - **Loading States**: Replaces icons with progress indicators when appropriate
    ///
    /// ## Visual States
    /// - **Selected**: Highlighted color and additional visual indicators
    /// - **Unselected**: Dimmed color for secondary appearance
    /// - **Loading**: Progress spinner replaces static icon
    /// - **Notifications**: Red badge overlay for profile tab
    ///
    /// - Parameter tab: The tab configuration to render
    @ViewBuilder private func TabItem(tab: BottomTab) -> some View {
        if tab == BottomTab.profile, let currentUser = userStore.currentUser {
            // Profile tab with user's profile picture
            UserPfpAsyncView(pfp: currentUser.profilePic, size: 24, quality: .low)
                .overlay(
                    Circle()
                        .inset(by: -0.25)
                        .stroke(Color.theme.iconPrimary, lineWidth: activeTab == tab ? 1 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    // Notification badge
                    if tabCoordinator.hasNotification {
                        Circle()
                            .fill(Color.theme.strokeBgMatch)
                            .frame(8 + 2)
                            .overlay {
                                Circle()
                                    .fill(Color.theme.red)
                                    .frame(8)
                            }
                            .offset(x: 2, y: -2)
                    }
                }
        } else {
            // Standard icon tabs with loading state support
            if tabCoordinator.isFlicksFeedRefreshing, tab == .flicks {
                CliqueProgressView(size: 24)
            } else {
                IconImage(
                    name: tab.image,
                    color: tabColor(tab, activeTab),
                    size: 24
                )
            }
        }
    }
    
    /// Determines the appropriate color for a tab based on its type and selection state.
    ///
    /// This function implements the app's tab coloring strategy, providing visual
    /// hierarchy through color differentiation. It ensures the create tab stands out
    /// while maintaining clear selection states for navigation tabs.
    ///
    /// ## Color Strategy
    /// - **Create Tab**: Always pink to emphasize creation actions
    /// - **Selected Tab**: Primary selected color for current tab
    /// - **Unselected Tabs**: Dimmed secondary color
    ///
    /// ## Theme Integration
    /// All colors use semantic theme colors that automatically adapt to:
    /// - Light/dark mode changes
    /// - User accessibility preferences
    /// - App-wide theme updates
    ///
    /// - Parameters:
    ///   - tab: The tab to determine color for
    ///   - activeTab: The currently active tab for comparison
    /// - Returns: Appropriate semantic color for the tab's current state
    private func tabColor(_ tab: BottomTab, _ activeTab: BottomTab) -> Color {
        if tab == .create {
            return Color.theme.cliquePink
        } else if tab == activeTab {
            return Color.theme.navbarSelectedTab
        } else {
            return Color.theme.navbarUnselectedTab
        }
    }
}

#Preview {
    MainTabView()
        .environment(TabViewCoordinator())
        .environment(UserStore())
        .environment(AppCoordinator())
}
