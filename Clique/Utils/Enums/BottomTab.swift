//
//  BottomTab.swift
//  Clique
//
//  Created by Rod Tavangar on 7/16/24.
//

import SwiftUI

enum BottomTab: String, Identifiable, CaseIterable {
    var id: String { self.rawValue }
    
    case flicks = "Flicks"
    case search = "Search"
    case create = "Create"
    case collections = "Collections"
    case profile = "Profile"
    
    var title: String { self.rawValue }
    
    var image: String {
        switch self {
        case .flicks:
            return "posts"
        case .collections:
            return "collections"
        case .create:
            return "clique-star"
        case .search:
            return "search"
        case .profile:
            return "user"
        }
    }
}
