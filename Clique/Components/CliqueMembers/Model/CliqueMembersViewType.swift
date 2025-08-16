//
//  CliqueMembersViewType.swift
//  Clique
//
//  Created by Rod Tavangar on 10/29/24.
//

import SwiftUI

/// Where CliqueMembersView is being shown
enum CliqueMembersViewType {
    case cliqueProfile
    case cliqueListCell
    case collection
    case collectionPreview
    case comments
    case sharePostTagged
    case cliqueHub
    case cliqueCreator
    case cliquePicker
    
    case medium
    case large
    
    var spacing: CGFloat {
        switch self {
        case .cliqueProfile, .collection, .comments, .sharePostTagged, .cliqueCreator, .collectionPreview, .medium, .large:
            return -8
        case .cliqueListCell, .cliqueHub, .cliquePicker:
            return -4
        }
    }
    
    var size: CGSize {
        switch self {
        case .cliqueListCell, .cliqueHub, .cliquePicker:
            return .init(width: 16, height: 16)
            
        case .comments, .collectionPreview, .medium:
            return .init(width: 24, height: 24)
            
        case .cliqueProfile, .collection, .sharePostTagged, .cliqueCreator, .large:
            return .init(width: 32, height: 32)
        }
    }
    
    var inset: Double {
        switch self {
        case .cliqueProfile, .collection, .comments, .sharePostTagged, .cliqueCreator, .collectionPreview, .medium, .large:
            return -1
        case .cliqueListCell, .cliqueHub, .cliquePicker:
            return -0.5
        }
    }
    
    var strokeColor: Color {
        switch self {
        case .cliquePicker:
            return Color.theme.white
        default:
            return Color.theme.strokeBgMatch
        }
    }
    
    var strokeWidth: CGFloat {
        switch self {
        case .cliqueListCell, .cliqueHub, .cliquePicker:
            return 1
            
        case .cliqueProfile, .collection, .comments, .sharePostTagged, .cliqueCreator, .collectionPreview, .medium, .large:
            return 2
        }
    }
    
    
    // TODO: member limit and show difference should be parameters in CliqueCircularMembersView
    var memberLimit: Int {
        switch self {
        case .comments:
            return 2
        case .cliqueCreator:
            return 4
        case .collection, .cliqueProfile, .collectionPreview, .medium, .large:
            return 5
        case .sharePostTagged, .cliqueHub:
            return 10
        case .cliqueListCell, .cliquePicker:
            return 22
        }
    }
    
    var showDifference: Bool {
        switch self {
        case .cliqueProfile:
            return true
        default:
            return false
        }
    }
}
