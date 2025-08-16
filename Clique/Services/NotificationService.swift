//
//  NotificationService.swift
//  Clique
//
//  Created by Rod Tavangar on 4/10/25.
//

import Foundation

final class NotificationService {
    static func getUserNotifications(_ input: Operations.getNotificationsByUser.Input) async throws -> [UserNotification] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getNotificationsByUser(input) {
        case .ok(let response):
            switch response.body {
            case .json(let notifications):
                return mapToUserNotifications(notifications)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get notifications by user failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func getNotificationStatus(_ input: Operations.getNotificationStatus.Input) async throws -> Bool {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getNotificationStatus(input) {
        case .ok(let response):
            switch response.body {
            case .json(let status):
                return status.hasAlert ?? false
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get notification status failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func getNotificationInviteStatus(_ input: Operations.getNotificationInviteStatus.Input) async throws -> Bool {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getNotificationInviteStatus(input) {
        case .ok(let response):
            switch response.body {
            case .json(let status):
                return status.hasAlert ?? false
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get notification status failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func markNotificationsAsRead(_ input: Operations.markNotificationsAsRead.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.markNotificationsAsRead(input) {
        case .ok:
            print("marked as read")
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: mark notifications as read failed")
        }
        throw ServiceError.somethingWentWrong
    }
}
