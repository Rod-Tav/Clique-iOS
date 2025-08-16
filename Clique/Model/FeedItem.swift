//
//  FeedItem.swift
//  Clique
//
//  Created by Rod Tavangar on 11/19/24.
//

import Foundation

struct FeedItem: Identifiable, Hashable, Codable {
    let id: String
    var relevantUser: User?
    var collection: ClCollection?
    var clique: Clique
}

//extension FeedItem {
//    static var MOCK_FEEDCELLITEMS: [FeedItem] = [
//        .collection(ClCollection.MOCK_COLLECTIONS[0]),
//        .collection(ClCollection.MOCK_COLLECTIONS[1]),
//    ]
//}
