//
//  CliqueProfileTab.swift
//  Clique
//
//  Created by Rod Tavangar on 7/11/24.
//

import SwiftUI

enum CliqueProfileTab: Int, CaseIterable, Identifiable, ProfileTab {
    case recents = 0
    case collections = 1
    
    var title: String {
        switch self {
        case .recents:
            return "RECENTS"
        case .collections:
            return "COLLECTIONS"
        }
    }
    
    var icon: String {
        switch self {
        case .recents:
            return "time-clock-recents"
        case .collections:
            return "collections"
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
        case .recents:
            return "No recent activity."
        case .collections:
            return "Nothing here yet."
        }
    }
    
    var callToActionString: String {
        switch self {
        case .recents:
            return "Why don't you add some flicks?"
        case .collections:
            return "Why don't you start a collection?"
        }
    }
    
    var callToActionButtonTitle: String {
        switch self {
        case .recents:
            return "Upload Flicks"
        case .collections:
            return "Create Collection"
        }
    }
    
    var id: Int {
        return self.rawValue
    }
}
