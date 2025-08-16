//
//  UserRelationshipDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 2/5/25.
//

import Foundation

enum UserRelationship: Codable {
//    case mutualFollowing // currentUser is a mutual follower with the other user
    case following // currentUser follows the other user
    case requested // currentUser has requested the other user
    case unrelated // could make this an optional
    
    var buttonType: SmallCTAType {
        switch self {
        case .following: return .secondary
        case .requested: return .tertiary
        case .unrelated: return .primary
        }
    }
    
    var leadingIcon: String {
        switch self {
        case .following: return "check"
        case .requested: return "time-clock-recents"
        case .unrelated: return "plus"
        }
    }
    
    var buttonText: String {
        switch self {
        case .following: return "Following"
        case .requested: return "Requested"
        case .unrelated: return "Follow"
        }
    }
}

func mapToUserRelationship(_ rel: Components.Schemas.FollowStatus) -> UserRelationship {
    switch rel {
    case .FOLLOWING: .following
    case .REQUESTED: .requested
    case .NONE: .unrelated
    }
}
