//
//  CommentDTO.swift
//  Clique
//
//  Created by Quinn Liu on 2/7/25.
//

import SwiftUI
import Foundation

func mapToComment(_ comment: Components.Schemas.Comment, isLiked: Bool = false) -> Comment {
    return Comment(
        id: comment.commentId!,
        text: comment.payload!,
        author: mapToUser(comment.user!),
        numLikes: comment.likeCount!,
        numReplies: comment.replyCount!,
        dateCreated: convertToDate(comment.dateCreated!),
        hasLiked: isLiked
    )
}

func mapToComment(_ data: Components.Schemas.CommentWLiked) -> Comment {
    return mapToComment(data.comment!, isLiked: data.isLiked!)
}

func mapToComment(_ data: Components.Schemas.CommentResponseBody) -> Comment {
    let comment = data.comment!
    return mapToComment(comment)
}

func mapToComments(_ data: Components.Schemas.CommentsResponseBody) -> [Comment] {
    return data.comments!.map { mapToComment($0) }
}
