////
////  NotificationsViewModel.swift
////  Clique
////
////  Created by Quinn Liu on 1/31/25.
////
//
//import Foundation
//
//@Observable
//class NotificationsViewModel {
//    var notifications: [UserNotification]
//    var cliqueInvitations: [UserNotification]
//    var followRequests: [UserNotification]
//    var groupedNotifications: [NotificationSection: [UserNotification]] = [:]
//    
//    init(notifications: [UserNotification] = [], cliqueInvitations: [UserNotification] = [], followRequests: [UserNotification] = []) {
//        self.notifications = notifications
//        self.cliqueInvitations = cliqueInvitations
//        self.followRequests = followRequests
//    }
//    
//    func acceptInvitation(_ notification: UserNotification) {
//        if notification.type == .cliqueInvite {
//            if let index = cliqueInvitations.firstIndex(where: {$0.id == notification.id}) {
//                cliqueInvitations[index].accepted = true
//            }
//        } else if notification.type == .followRequest {
//            if let index = followRequests.firstIndex(where: {$0.id == notification.id}) {
//                followRequests[index].accepted = true
//            }
//        }
//        if let index = notifications.firstIndex(where: {$0.id == notification.id}) {
//            notifications[index].accepted = true
//        }
//    }
//    
////    func loadMockNotifications() {
////        for notification in UserNotification.MOCK_NOTIFICATIONS {
////            if notification.type == .cliqueInvite {
////                cliqueInvitations.append(notification)
////            } else if notification.type == .followRequest {
////                followRequests.append(notification)
////            }
////            
////            notifications.append(notification)
////        }
////        
////        let sortedNotifications = notifications.sorted { $0.time > $1.time }
////        groupedNotifications = Dictionary(grouping: sortedNotifications, by: { $0.section })
////    }
//}
