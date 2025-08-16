//
//  NotificationType.swift
//  Clique
//
//  Created by Rod Tavangar on 11/28/24.
//

import SwiftUI

enum NotificationType: String, Codable {
    var id: String { rawValue }
    
    case followRequest // private account
    case followedYou // public account
    case acceptedFollowRequest
    
    case createdCollection
    case postedFlick // TODO: rename
    
    case newCliqueLeader
    case cliqueInvite
    case cliqueJoined
    case cliqueLeft
    
    case taggedInFlicks
    
    case likedFlickInCollection
    
    case commentedOnPost
    case commentedInCollection
    case mentionedYouInComment
    
    var notificationMessage: String {
        switch self {
        case .followRequest:
            "requested to follow you"
        case .followedYou:
            "started following you"
        case .acceptedFollowRequest:
            "accepted your follow request"
        case .createdCollection:
            "created X"
        case .postedFlick:
            "posted a flick"
        case .newCliqueLeader:
            "is now the Clique Leader"
        case .cliqueInvite:
            "invited you to their Clique"
        case .cliqueJoined:
            "joined your Clique"
        case .cliqueLeft:
            "left your Clique"
        case .taggedInFlicks:
            "tagged you in X flicks"
        case .likedFlickInCollection:
            "liked a flick in your collection"
        case .commentedOnPost:
            "commented on your post"
        case .commentedInCollection:
            "commented in"
        case .mentionedYouInComment:
            "mentioned you in a comment"
        }
    }
    
    var notificationSymbol: String {
        switch self {
        case .postedFlick:
            return "posts"
        case .likedFlickInCollection:
            return "heart-filled"
        case .cliqueInvite, .cliqueJoined, .cliqueLeft:
            return "3-user"
        case .followRequest, .followedYou, .acceptedFollowRequest:
            return "add-user"
        case .commentedOnPost, .commentedInCollection, .mentionedYouInComment:
            return "chat"
        case .createdCollection:
            return "collections"
        case .newCliqueLeader:
            return "crown-leader"
        case .taggedInFlicks:
            return "camera"
        }
    }
    
    var notificationSymbolColor: Color {
        switch self {
        case .postedFlick, .cliqueInvite, .cliqueJoined, .cliqueLeft, .createdCollection, .taggedInFlicks:
            return Color.theme.iconPrimary
        case .likedFlickInCollection:
            return Color.theme.red
        case .followRequest, .followedYou, .acceptedFollowRequest:
            return Color.theme.purple
        case .commentedOnPost, .commentedInCollection, .mentionedYouInComment:
            return Color.theme.skyblue
        case .newCliqueLeader:
            return Color.theme.gold
        }
    }
}
