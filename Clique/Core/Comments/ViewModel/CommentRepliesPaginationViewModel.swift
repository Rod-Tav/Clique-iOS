//
//  CommentRepliesPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/14/25.
//

import Foundation

@Observable final class CommentRepliesPaginationViewModel: PaginationViewModel {
    typealias Item = String
    typealias Input = CommentRepliesPaginationFetchInput
    
    var items: [String] = []
    var query: String = ""
    
    var page: Int = 0
    var size: Int { 5 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CommentRepliesPaginationFetchInput) async throws -> [String]
    
    private var parentId: String
    
    init(parentId: String, _ commentStore: CommentStore) {
        self.parentId = parentId
//        print("parentid: \(parentId)")
        self.fetchFunction = { input in
            let comments = try await CommentService.getRepliesByComment(.init(path: .init(commentId: input.parentId), query: .init(page: input.page, size: input.size)))
            
            await commentStore.updateComments(comments)
            
            return comments.map( { $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> CommentRepliesPaginationFetchInput {
        return CommentRepliesPaginationFetchInput(parentId: parentId, page: page, size: size)
    }
}

