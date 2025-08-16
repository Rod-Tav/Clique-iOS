//
//  UserListConfig.swift
//  Clique
//
//  Created by Rod Tavangar on 6/16/24.
//

import Foundation

// TODO: deprecate
enum UserListConfig: Hashable {
    case followers(uid: String)
    case following(uid: String)
    case likes(postId: String)
    case search
    case members(cliqueID: String)
    
    var navigationTitle: String {
        switch self {
        case.followers:
            return "Followers"
        case .following:
            return "Following"
        case .likes:
            return "Likes"
        case .search:
            return "Search"
        case .members:
            return "Members"
        }
    }
}
