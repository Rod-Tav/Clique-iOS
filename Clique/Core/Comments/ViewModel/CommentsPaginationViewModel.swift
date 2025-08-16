//
//  CommentsPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/11/25.
//

import Foundation

@Observable final class CommentsPaginationViewModel: PaginationViewModel {
    typealias Item = String // comment id
    typealias Input = CommentsPaginationFetchInput
    
    var items: [String] = []
    var query: String = ""
    
    var page: Int = 0
    var size: Int { 15 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (CommentsPaginationFetchInput) async throws -> [String]
    
    private var parentTypeId: String
    
    init(collectionItemId: String, _ commentStore: CommentStore, _ userStore: UserStore) {
        self.parentTypeId = collectionItemId
        self.fetchFunction = { input in
            let comments = try await CommentService.getCommentsByCollectionImage(.init(path: .init(collectionItemId: input.parentTypeId), query: .init(page: input.page, size: input.size)))
            
            let users = comments.map { $0.author }
            
            await userStore.updateUsers(users)
            
            await commentStore.updateComments(comments)
            
            return comments.map( { $0.id })
        }
    }
    
    func makeInput(page: Int, size: Int) -> CommentsPaginationFetchInput {
        return CommentsPaginationFetchInput(parentTypeId: parentTypeId, page: page, size: size)
    }
}

extension CommentsPaginationViewModel {
    func removeComment(id: String) {
        items.removeAll(where: { $0.id == id })
    }
}
