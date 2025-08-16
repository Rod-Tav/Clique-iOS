//
//  NotificationNames.swift
//  Clique
//
//  Created by Rod Tavangar on 7/10/25.
//

import SwiftUI

struct ReceiveNotificationModifier: ViewModifier {
    let name: Notification.Name
    let action: (NotificationCenter.Publisher.Output) -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: name)) { notification in
                action(notification)
            }
    }
}

extension View {
    func onReceive(of name: Notification.Name, action: @escaping (NotificationCenter.Publisher.Output) -> Void) -> some View {
        self
            .modifier(ReceiveNotificationModifier(name: name, action: action))
    }
}

extension NotificationCenter.Publisher.Output {
    func checkEquals(_ s: String) -> Bool {
        if let y = self.object as? String, y == s {
            return true
        } else {
            return false
        }
    }
    
    func contains(_ s: String) -> Bool {
        if let y = self.object as? [String], y.contains(s) {
            return true
        } else {
            return false
        }
    }
}

func trigger(_ name: Notification.Name, object: Any? = nil) {
    NotificationCenter.default.post(name: name, object: object)
}

extension Notification.Name {
    // MARK: - Content Refresh Triggers
    
    /// Triggers refresh of specific collection's images (pass collection ID as object)
    static let refreshCollectionImages = Notification.Name("refreshCollectionImages")
    
    /// Triggers refresh of specific clique feed (pass clique ID as object)
    static let refreshCliqueFeed = Notification.Name("refreshCliqueFeed")
    
    /// Triggers refresh of collection cells (pass array of collection IDs as object)
    static let refreshCollectionCells = Notification.Name("refreshCollectionCells")
    
    /// Triggers refresh of current user's cliques list
    static let refreshUserCliques = Notification.Name("refreshUserCliques")
    
    /// Triggers refresh of current user's collections list
    static let refreshUserCollections = Notification.Name("refreshUserCollections")
    
    /// Triggers refresh of the main home feed
    static let refreshHomeFeed = Notification.Name("refreshHomeFeed")
    
    /// Triggers refresh of the clique hub feed
    static let refreshCliqueHubFeed = Notification.Name("refreshCliqueHubFeed")
    
    /// Triggers refresh of the flicks feed
    static let refreshFlicksFeed = Notification.Name("refreshFlicksFeed")
    
    /// Triggers scroll to top of feed
    static let scrollToTopOfFeed = Notification.Name("scrollToTopOfFeed")
    
    // MARK: - Action Triggers
    
    /// Triggers the add photos cover flow
    static let addPhotosCover = Notification.Name("addPhotosCover")
    
    /// Triggers notification badge and count checking
    static let checkNotifications = Notification.Name("checkNotifications")
    
    /// Triggers inbox notification checking specifically
    static let checkInboxNotifications = Notification.Name("checkInboxNotifications")
    
    // MARK: - Navigation & UI Events
    
    /// Posted when a push notification is tapped
    static let didTapNotification = Notification.Name("didTapNotification")
    
    /// Triggers image upload to a collection (pass collection info as object)
    static let uploadImagesToCollection = Notification.Name("uploadImagesToCollection")
    
    /// Shows processing indicator for image uploads
    static let showProcessingImagesForUpload = Notification.Name("processingImagesForUpload")
    
    /// Focuses the search tab's search field
    static let focusSearchTab = Notification.Name("focusSearchTab")
    
    /// Opens the photo library in create flow
    static let openLibrary = Notification.Name("openLibrary")
    
    /// Triggers camera reset
    static let cameraReset = Notification.Name("cameraReset")
}
