//
//  FeedItemCellView.swift
//  Clique
//
//  Created by Rod Tavangar on 1/25/25.
//

import SwiftUI

struct FeedItemCellView: View {
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CommentStore.self) private var commentStore
    
    let feedItem: FeedItem
    
    var body: some View {
        if let collectionId = feedItem.collection?.id,
           let cid = feedItem.collection?.cliqueId,
           let clique = cliqueStore.cliques[cid],
           let imageIds = collectionStore.collections[collectionId]?.images.map({ $0.id })
        {
            CollectionFeedCellView(
                collectionId: collectionId,
                clique: clique,
                relevantUser: feedItem.relevantUser,
                initialImageIds: imageIds,
                collectionStore,
                collectionImageStore
            )
        }
    }
}

//#Preview {
//    FeedItemCellView(FeedItem.MOCK_FEEDCELLITEMS[0])
//}
