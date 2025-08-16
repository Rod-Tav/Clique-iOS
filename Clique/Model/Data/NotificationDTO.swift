//
//  NotificationDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 4/10/25.
//

import Foundation

func mapToNotificationType(_ data: Components.Schemas.NotificationEntityType) -> NotificationType {
    switch data {
    case .FOLLOW_REQ_ACCEPTED:
            .acceptedFollowRequest
    case .USER_NOW_FOLLOWING:
            .followedYou
    case .CREATED_COLLECTION:
            .createdCollection
    case .POSTED_TO_COLLECTION:
            .postedFlick
    case .JOINED_CLIQUE:
            .cliqueJoined
    case .LEFT_CLIQUE:
            .cliqueLeft
    case .LIKED_COLLECTION_ITEM:
            .likedFlickInCollection
    case .LIKED_COMMENT: // TODO: implement in NotificationType
            .likedFlickInCollection
    case .COMMENTED_ON_COLLECTION_ITEM:
            .commentedInCollection
    case .TAGGED_IN_COMMENT:
            .mentionedYouInComment
    case .REPLY_RECEIVED: // TODO: implement in NotificationType
            .likedFlickInCollection
    }
}

func mapToUserNotifications(_ data: Components.Schemas.GetNotificationsResponseBody) -> [UserNotification] {
    let notis = data.notifications!
    return notis.map(mapToUserNotification)
}

func mapToUserNotification(_ data: Components.Schemas.UserNotification) -> UserNotification {
    return UserNotification(
        id: data.notificationId!,
        type: mapToNotificationType(data.notificationType!),
        user: mapToUser(data.relevantUser!),
        time: convertToDate(data.dateCreated),
        clique: data.clique == nil ? nil : mapToClique(data.clique!),
        comment: data.comment,
        collection: data.collectionData == nil ? nil : mapToCollection(collectionData: data.collectionData!, images: []),
        collectionImage: data.collectionItem == nil ? nil : mapToCollectionImage(data.collectionItem!),
        viewed: data.isRead
    )
}
