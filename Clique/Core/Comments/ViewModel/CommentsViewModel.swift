//
//  CommentsViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/15/24.
//

import Foundation

struct ReplyComment: Equatable {
    let comment: Comment
    let parentId: String

    static func == (lhs: ReplyComment, rhs: ReplyComment) -> Bool {
        return lhs.comment.id == rhs.comment.id && lhs.parentId == rhs.parentId
    }
}

@Observable final class CommentsViewModel {
    var replyingToComment: Comment?
    var isScrolling: Bool = false
    var replyComment: ReplyComment? = nil // comment and parentId
    
    private var collectionItemId: String?

    init (collectionItemId: String) {
        self.collectionItemId = collectionItemId
    }
    
    func createComment(text: String, parentId: String?) async throws -> Comment {
        return try await CommentService.createComment(.init(body: .json(.init(payload: text, collectionItemId: collectionItemId, parentId: parentId))))
    }
}
