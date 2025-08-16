//
//  CommentService.swift
//  Clique
//
//  Created by Rod Tavangar on 7/15/24.
//

import Foundation

class CommentService {
    //    let postID: String
    //    let collectionImageID: String
    //
    //    init(postID: String) {
    //        self.postID = postID
    //        self.collectionImageID = ""
    //    }
    //
    //    init(collectionImageID: String) {
    //        self.collectionImageID = collectionImageID
    //        self.postID = ""
    //    }
    
    //    func uploadComment(_ comment: Comment) async throws {
    //
    //    }
    //
    //    func fetchComments() async throws -> [Comment] {
    //        return /*Comment.MOCK_COMMENTS*/ []
    //    }
}

// MARK: - Get comments
extension CommentService {
    static func getCommentsByCollectionImage(_ input: Operations.getCommentsByCollectionItem.Input) async throws -> [Comment] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCommentsByCollectionItem(input) {
        case .ok(let response):
            switch response.body {
            case .json(let comments):
                return mapToComments(comments)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get comments by collection image failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func getRepliesByComment(_ input: Operations.getRepliesByComment.Input) async throws -> [Comment] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getRepliesByComment(input) {
        case .ok(let response):
            switch response.body {
            case .json(let comments):
                return mapToComments(comments)
            }
        default:
            print("DEBUG: get replies by comment failed")
            throw ServiceError.somethingWentWrong
        }
    }
}

// MARK: - Create comment
extension CommentService {
    static func createComment(_ input: Operations.createComment.Input) async throws -> Comment {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.createComment(input) {
        case .ok(let response):
            switch response.body {
            case .json(let comment):
                let comment = mapToComment(comment)
                
                if case let .json(requestBody) = input.body {
                    track(
                        event: "Created Comment",
                        properties: [
                            "commentId": comment.id,
                            "flickId": comment.collectionItemId,
                            "isReply": requestBody.parentId != nil
                        ]
                    )
                }
                
                return comment
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: create comment failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Like comment
extension CommentService {
    static func likeComment(_ input: Operations.likeComment.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.likeComment(input) {
        case .ok:
            track(
                event: "Liked Comment",
                properties: [
                    "commentId": input.path.commentId
                ]
            )
            
            return
        default:
            print("DEBUG: like comment failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func unlikeComment(_ input: Operations.unlikeComment.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.unlikeComment(input) {
        case .ok:
            track(
                event: "Unliked Comment",
                properties: [
                    "commentId": input.path.commentId
                ]
            )
            
            return
        default:
            print("DEBUG: unlike comment failed")
            throw ServiceError.somethingWentWrong
        }
    }
}

// MARK: - Delete comment
extension CommentService {
    static func deleteComment(_ input: Operations.deleteComment.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.deleteComment(input) {
        case .ok:
            track(
                event: "Deleted Comment",
                properties: [
                    "commentId": input.path.commentId
                ]
            )
            
            return
        default:
            print("DEBUG: delete comment failed")
            throw ServiceError.somethingWentWrong
        }
    }
}

