//
//  AppService.swift
//  Clique
//
//  Created by Rod Tavangar on 3/4/25.
//

import FirebaseFirestore
import SwiftUI

class AppService {
    @AppStorage("hasRegisteredForPush") static var hasRegisteredForPush: Bool = false
    @AppStorage("badgeCount") static var badgeCount: Int = 0
    @AppStorage("userToken") static var userToken: String = ""
    
    /// Decrement badge count and sync with system badge
    static func decrementAppBadge() {
//        guard badgeCount > 0 else { return } // Avoid negative badge count
//        let newBadgeCount = badgeCount - 1
//        
//        UNUserNotificationCenter.current().setBadgeCount(newBadgeCount) { error in
//            if let error = error {
//                print("❌ Failed to set badge count: \(error.localizedDescription)")
//            } else {
//                print("✅ Badge count updated to \(newBadgeCount)")
//                badgeCount = newBadgeCount
//            }
//        }
//        DispatchQueue.main.async {
//            UIApplication.shared.applicationIconBadgeNumber -= 1
//        }
    }
    
    /// Reset badge count to zero and clear system badge
    static func resetAppBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Failed to reset badge count: \(error.localizedDescription)")
            } else {
                print("✅ Badge count reset to 0")
                badgeCount = 0
            }
        }
    }
    
    static func isUpdateAvailable(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("app_config").document("latest_version").getDocument { document, error in
            if let document = document, document.exists,
               let latestVersion = document.data()?["version"] as? String {
                completion(latestVersion != AppConfig.currentVersion)
            } else {
                completion(false) // Handle error or missing data by assuming no update
            }
        }
    }
    
    @MainActor static func checkAndRegisterPushNotificationsIfNeeded(userStore: UserStore) {
        // ✅ Only handle notifications if user is fully signed up
//        guard userStore.currentUser != nil else {
//            print("⚠️ User is not fully registered yet — skipping notifications check.")
//            return
//        }
        print("checking")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                print("✅ Notifications are authorized")
                
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied:
                print("❌ Notifications denied. Prompt user to enable in Settings.")
                hasRegisteredForPush = false // Reset to try again if enabled later
//                DispatchQueue.main.async {
                    requestPushNotificationPermissions()
//                }
            case .notDetermined:
                print("⚠️ Notifications not determined, requesting (only expected during Welcome screen).")
                hasRegisteredForPush = false
                requestPushNotificationPermissions()
                break
            @unknown default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let didReceiveDeviceToken = Notification.Name("didReceiveDeviceToken")
}

func saveToken(_ notification: NotificationCenter.Publisher.Output) throws {
    if let token = notification.userInfo?["token"] as? String {
        Task {
            try await UserService.updateUserDeviceToken(.init(body: .json(.init(deviceToken: token))))
            
            AppService.hasRegisteredForPush = true
        }
    }
}

func requestPushNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        if let error = error {
            print("❌ Authorization error: \(error.localizedDescription)")
            return
        }

        if granted {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
