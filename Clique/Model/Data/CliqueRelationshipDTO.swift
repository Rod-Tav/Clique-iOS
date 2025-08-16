//
//  CliqueRelationshipDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import Foundation

enum CliqueRelationship: Codable {
    case member, leader, following, unrelated
    
    var buttonType: SmallCTAType {
        switch self {
        case .following: return .secondary
        case .member: return .secondary
        case .leader: return .primary
        case .unrelated: return .primary
        }
    }
    
    var leadingIcon: String {
        switch self {
        case .following: return "check"
        case .member: return "3-user"
        case .leader: return "crown-leader"
        case .unrelated: return "plus"
        }
    }
    
    var buttonText: String {
        switch self {
        case .following: return "Following"
        case .member: return "Member"
        case .leader: return "Leader"
        case .unrelated: return "Follow"
        }
    }
    
    var isInClique: Bool {
        return self == .leader || self == .member
    }
}

func mapToCliqueRelationship(_ rel: Components.Schemas.CliqueMemberRoleStatus) -> CliqueRelationship {
    switch rel {
    case .MEMBER: .member
    case .OWNER: .leader
    case .FOLLOWING: .following
    case .NONE: .unrelated
    }
}
