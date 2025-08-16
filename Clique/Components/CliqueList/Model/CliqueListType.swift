//
//  CliqueListType.swift
//  Clique
//
//  Created by Rod Tavangar on 11/2/24.
//

import SwiftUI

enum CliqueListType: Equatable {
    case standard
    case cliqueInvite(fromUserPfp: PhotoUrls?, fromUserFirstName: String)
//    case cliquePicker
    
    var statColor: Color {
        switch self {
//        case .cliquePicker:
//            return .white.opacity(0.9)
        default:
            return Color.theme.textPrimary
        }
    }
    
    var descColor: Color {
        switch self {
//        case .cliquePicker:
//            return .white.opacity(0.8)
        default:
            return Color.theme.textSecondary
        }
    }
}
