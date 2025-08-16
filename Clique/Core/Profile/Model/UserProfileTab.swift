//
//  UserProfileTab.swift
//  Clique
//
//  Created by Rod Tavangar on 7/21/24.
//

import SwiftUI

enum UserProfileTab: Int, CaseIterable, Identifiable, ProfileTab {
//    case recents = 0
    case cliques = 0
    case collections = 1
    
    var title: String {
        switch self {
//        case .recents:
//            return "RECENTS"
        case .collections:
            return "COLLECTIONS"
        case .cliques:
            return "CLIQUES"
        }
    }
    
    var icon: String {
        switch self {
//        case .recents:
//            return "posts"
        case .collections:
            return "collections"
        case .cliques:
            return "3-user"
        }
    }
    
    var image: AnyView {
        AnyView(
            Image(self.icon)
                .resizable()
                .renderingMode(.template)
                .frame(16)
        )
    }
    
    var nothingHereString: String {
        switch self {
//        case .recents:
//            return "No recent activity."
        case .cliques, .collections:
            return "Nothing here yet."
        }
    }
    
    var callToActionString: String {
        switch self {
//        case .recents:
//            return "Why don't you add some flicks?"
        case .cliques:
            return "Why don't you have friends?"
        case .collections:
            return "Why don't you start a collection?"
        }
    }
    
    var callToActionButtonTitle: String {
        switch self {
//        case .recents:
//            return "Upload Flicks"
        case .cliques:
            return "Create a Clique"
        case .collections:
            return "Create Collection"
        }
    }
    
    var id: Int {
        return self.rawValue
    }
}
