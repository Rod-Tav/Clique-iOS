//
//  UserFlickItem.swift
//  Clique
//

import Foundation

/// Bundles a user's flick with its collection and clique context
/// Similar to InfiniteFeedItem but for the user's own flicks
struct UserFlickItem: Identifiable, Hashable {
    let flick: CollectionImage
    let collection: ClCollection
    let cliqueId: String?

    var id: String { flick.id }

    // Convenience accessors for backwards compatibility
    var collectionId: String? { collection.id }
    var collectionName: String? { collection.name }
}
