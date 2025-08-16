//
//  InfiniteFeedItemDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 6/26/25.
//

import Foundation

func mapToInfiniteFeedItems(_ data: Components.Schemas.InfiniteFeedResponseBody) -> [InfiniteFeedItem] {
    let items = data.feedItems!
    return items.map { mapToInfiniteFeedItem($0, cursor: data.encodedCursor!) }
}

func mapToInfiniteFeedItem(_ data: Components.Schemas.InfiniteFeedItem, cursor: String) -> InfiniteFeedItem {
    return InfiniteFeedItem(
        collection: mapToCollection(collectionData: data.collectionData!, images: []),
        cliqueMembers: mapToUsers(data.cliqueMembers!),
        flick: mapToCollectionImage(data.urlCollectionItem!),
        clique: mapToClique(data.clique!),
        cursor: cursor
    )
}
