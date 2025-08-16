//
//  CommentSheetModifier.swift
//  Clique
//
//  Created by Rod Tavangar on 3/3/25.
//

import SwiftUI

struct CommentSheetModifier: ViewModifier {
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Environment(UserStore.self) private var userStore
    @Environment(CommentStore.self) private var commentStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    let imageId: String?
    let fromCollectionDetail: Bool
    @Binding var showCommentSheet: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCommentSheet) {
                if let imageId, let collectionImage = collectionImageStore.images[imageId] {
                    CommentsView(
                        collectionImage: collectionImage,
                        commentCount: Binding(
                            get: { collectionImageStore.images[imageId]?.numComments ?? 0 },
                            set: { newValue in
                                collectionImageStore.images[imageId]?.numComments = newValue ?? 0
                            }
                        ),
                        fromCollectionDetail: fromCollectionDetail, commentStore,
                        userStore
                    )
                    .commentSheetModifiers()
                }
            }
    }
}

extension View {
    func commentSheet(
        imageId: String?,
        fromCollectionDetail: Bool,
        showCommentSheet: Binding<Bool>
    ) -> some View {
        self.modifier(CommentSheetModifier(imageId: imageId, fromCollectionDetail: fromCollectionDetail, showCommentSheet: showCommentSheet))
    }
}
