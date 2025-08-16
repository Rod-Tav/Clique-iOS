//
//  CliquePfpViewType.swift
//  Clique
//
//  Created by Rod Tavangar on 10/30/24.
//

import SwiftUI

enum CliquePfpViewType {
    case cliqueProfile
    case cliqueProfilePill
    case collection
    case feedCell
    case cliqueListCell
    case comments // TODO: confirm values
    case collectionPreview
    case editCliqueProfile // TODO: confirm values
    case sharePostTopBar
    case cliquehubCarousel
    case pinnedCliques
    case cliqueCreated
    case notification
    case postDetails
    case feedCellBanner
    case expanded
    
    case xSmall
    case small
    
//    var hasBorder: Bool {
//        switch self {
//        case .cliqueProfile, .collection, .collectionPreview, .cliqueListCell, .cliquehubCarousel, .pinnedCliques, .cliqueCreated:
//            return true
//        case .feedCell, .comments, .editCliqueProfile, .sharePostTopBar, .cliqueProfilePill:
//            return false
//        }
//    }
    
    var size: CGSize {
        switch self {
        case .xSmall:
            return .init(width: 36, height: 36)
        case .small:
            return .init(width: 64, height: 64)
        case .notification:
            return .init(width: 16, height: 16)
        case .collectionPreview:
            return .init(width: 24, height: 24)
        case .feedCell:
            return .init(width: 28, height: 28)
        case .comments, .postDetails, .feedCellBanner:
            return .init(width: 32, height: 32)
        case .sharePostTopBar, .cliqueProfilePill:
            return .init(width: 36, height: 36)
        case .collection, .pinnedCliques:
            return .init(width: 48, height: 48)
        case .cliqueListCell, .cliqueProfile, .cliquehubCarousel:
            return .init(width: 64, height: 64)
        case .editCliqueProfile:
            return .init(width: 80, height: 80)
        case .cliqueCreated:
            return .init(width: 128, height: 128)
        case .expanded:
            return .init(width: 256, height: 256)
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .xSmall: return 8
        case .small: return 16
        case .comments, .collectionPreview, .notification:
            return 4
        case .feedCell:
            return 6
        case .collection, .sharePostTopBar, .cliqueProfilePill, .postDetails, .feedCellBanner:
            return 8
        case .pinnedCliques:
            return 12
        case .cliqueProfile, .cliqueListCell, .cliquehubCarousel, .editCliqueProfile:
            return 16
        case .cliqueCreated:
            return 24
        case .expanded:
            return 48
        }
    }
    
    // the below only occur if hasBorder is true
    var inset: CGFloat {
        switch self {
        case .small: return -0.25
        case .collectionPreview, .cliqueListCell, .cliquehubCarousel, .postDetails, .feedCellBanner:
            return -0.75
        case .cliqueProfile, .collection, .pinnedCliques:
            return -1
        case .cliqueCreated:
            return -3
        case .expanded:
            return -5
        default:
            return -1
        }
    }
    
    var strokeColor: Color {
        switch self {
        case .small, .collectionPreview:
            return .theme.strokeSecondary
        case .cliqueListCell:
            return .black.opacity(0.15)
        case .cliqueProfile, .collection:
            return .theme.surfacesBackgroundPrimary
        case .cliquehubCarousel, .postDetails, .feedCellBanner:
            return .theme.strokeSecondary
        case .pinnedCliques:
            return .theme.surfacesBackgroundPrimary
        case .cliqueCreated, .expanded:
            return .theme.buttonTertiary
        default:
            return .white
        }
    }
    
    var lineWidth: CGFloat {
        switch self {
        case .small: return 0.5
        case .cliqueListCell, .cliquehubCarousel, .postDetails, .feedCellBanner:
            return 0.5
        case .collectionPreview:
            return 1.5
        case .cliqueProfile, .collection, .pinnedCliques:
            return 2
        case .cliqueCreated, .expanded:
            return 6
        default:
            return 2
        }
    }
}
