//
//  CommentViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/12/25.
//

import Foundation

final class CommentViewModel {
    func likeComment(id: String) async throws {
        try await CommentService.likeComment(.init(path: .init(commentId: id)))
    }
    
    func unlikeComment(id: String) async throws {
        try await CommentService.unlikeComment(.init(path: .init(commentId: id)))
    }
    
    func deleteComment(id: String) async throws {
        try await CommentService.deleteComment(.init(path: .init(commentId: id)))
    }
}
