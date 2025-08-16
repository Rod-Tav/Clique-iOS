//
//  CommentStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/24/25.
//

import Foundation

@Observable @MainActor final class CommentStore {
    var comments = [String: Comment]() // id to Comment
    
    func updateComment(_ comment: Comment) {
        guard var existingComment = comments[comment.id] else {
            comments[comment.id] = comment // If comment doesn't exist, add it directly
            return
        }
        
        // Update only fields that have changed
        if existingComment.text != comment.text {
            existingComment.text = comment.text
        }
        if existingComment.postId != comment.postId {
            existingComment.postId = comment.postId
        }
        if existingComment.collectionItemId != comment.collectionItemId {
            existingComment.collectionItemId = comment.collectionItemId
        }
        if existingComment.numLikes != comment.numLikes {
            existingComment.numLikes = comment.numLikes
        }
        if existingComment.numReplies != comment.numReplies {
            existingComment.numReplies = comment.numReplies
        }
        if existingComment.hasLiked != comment.hasLiked {
            existingComment.hasLiked = comment.hasLiked
        }
        
        comments[comment.id] = existingComment
    }
    
    func updateComments(_ newComments: [Comment]) {
        newComments.forEach { updateComment($0) }
    }
    
    func reset() {
        comments = [String: Comment]()
    }
}
