//
//  InfiniteFeedItem.swift
//  Clique
//
//  Created by Rod Tavangar on 6/26/25.
//

import Foundation

struct InfiniteFeedItem: Identifiable, Hashable, Codable {
    var collection: ClCollection
    var cliqueMembers: [User]
    var flick: CollectionImage
    var clique: Clique
    var cursor: String
    
    var id: String {
        flick.id
    }
}
