//
//  CollectionDeepLinkDestination.swift
//  Clique
//
//  Created by Claude Code
//

import Foundation

/// Navigation destinations for collection deep link error states
enum CollectionDeepLinkDestination: Hashable {
    case networkError(collectionId: String)
    case notFound
    case accessDenied
    case notAuthenticated
}
