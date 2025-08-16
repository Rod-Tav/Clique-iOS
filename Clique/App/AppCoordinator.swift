//
//  AppCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 2/9/25.
//

import Foundation
import Toasts

/// Global coordinator managing app-wide state and cross-feature communication.
///
/// This coordinator serves as the central nervous system for the app, managing
/// global state and providing a notification-based trigger system for features
/// to communicate without tight coupling.
///
/// ## Architecture Pattern
/// The coordinator uses NotificationCenter for cross-feature communication:
/// - Features post notifications using `trigger()` method
/// - Other features observe notifications using `.onReceive(of:)`
/// - All notification names are defined in ``NotificationNames``
///
/// ## Key Responsibilities
/// - **Cross-Feature Communication**: Posting notifications for feature coordination
/// - **Global State Management**: Tracking app-wide flags and settings
/// - **Navigation Context**: Providing context for navigation decisions
/// - **Scroll State Tracking**: Managing scroll states to prevent navigation during scrolling
/// - **Toast Management**: Controlling toast notification positioning
///
/// ## Trigger System Example
/// ```swift
/// // Feature A wants to refresh the home feed
/// trigger(.refreshHomeFeed)
/// 
/// // Feature B observes this notification
/// .onReceive(of: .refreshHomeFeed) { _ in
///     await updateHomeFeed(.refresh)
/// }
/// 
/// // Pass data with notifications
/// trigger(.refreshCliqueFeed, object: cliqueId)
/// ```
///
/// ## Integration
/// Injected as environment object in ``CliqueApp`` and available throughout the app:
/// ```swift
/// @Environment(AppCoordinator.self) private var appCoordinator
/// ```
///
/// - Important: Always access from @MainActor context for thread safety
/// - Note: All trigger notifications are defined in ``NotificationNames``
@Observable @MainActor final class AppCoordinator {
    // MARK: - UI Configuration
    
    /// Position for toast notifications throughout the app
    var toastPosition: ToastPosition = .top
    
    // MARK: - Navigation and State Tracking
    
    /// Set of clique IDs that have active feed views (for background refresh)
    var activeCliqueFeeds: Set<String> = []
    
    /// Flag to open notification center (typically from push notification tap)
    var shouldOpenNotificationCenter: Bool = false
    
    /// Context flag indicating user is viewing profile from collection detail
    var lookingAtUserProfileFromCollectionDetail: Bool = false
    
    /// Flag to track when HeaderPageScrollView is actively scrolling
    /// Used to disable navigation during scroll operations
    var isHeaderPageScrolling: Bool = false
}
