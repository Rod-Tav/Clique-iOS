//
//  UserFlickItem.swift
//  Clique
//

import Foundation

/// Bundles a user's flick with its collection and clique context
/// Similar to InfiniteFeedItem but for the user's own flicks
struct UserFlickItem: Identifiable, Hashable {
    let flick: CollectionImage
    let collectionId: String?
    let collectionName: String?
    let cliqueId: String?

    var id: String { flick.id }
}
