//
//  FeedItemDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 2/28/25.
//

import Foundation

func mapToFeedItem(_ data: Components.Schemas.FeedItem) -> FeedItem {
    return FeedItem(
        id: data.feedItemId!,
        relevantUser: data.relevantUser == nil ? nil : mapToUser(data.relevantUser!),
        collection: data.collection == nil ? nil : mapToCollection(data.collection!),
        clique: mapToClique(data.clique!)
    )
}

func mapToFeedItems(_ data: Components.Schemas.FeedResponseBody) -> [FeedItem] {
    return data.feedItems!.map { mapToFeedItem($0) }
}
