//
//  UserListCellViewType.swift
//  Clique
//
//  Created by Rod Tavangar on 11/1/24.
//

import SwiftUI

enum UserListCellViewType {
    case sharepostTaggedSelected
    case sharepostTaggedSuggested
    case search
    case searchRecents
    case createClique
    case cliqueMembersList
    case taggedPost
    case contacts
    
    case small
    case large
    
    var size: CGFloat {
        switch self {
        case .searchRecents, .sharepostTaggedSuggested, .createClique, .small:
            return 32
        case .sharepostTaggedSelected, .search, .cliqueMembersList, .taggedPost, .large, .contacts:
            return 48
        }
    }
    
    var quality: ImageQuality {
        switch self {
        case .searchRecents, .sharepostTaggedSuggested, .createClique, .small:
            return .low
        case .sharepostTaggedSelected, .search, .cliqueMembersList, .taggedPost, .large, .contacts:
            return .medium
        }
    }
}
