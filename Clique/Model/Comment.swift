//
//  Comment.swift
//  Clique
//
//  Created by Rod Tavangar on 7/15/24.
//

import Foundation

struct Comment: Identifiable, Codable, Hashable {
    let id: String
    var text: String
    var postId: String? = ""
    var collectionItemId: String? = ""
    let author: User
    var numLikes: Int = 0
    var numReplies: Int = 0
    var dateCreated: Date = Date()
    var hasLiked: Bool = false
    
//    static func == (lhs: Comment, rhs: Comment) -> Bool {
//        return lhs.id == rhs.id
//    }
    
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
}

extension Comment {
    static var MOCK_COMMENTS: [Comment] = [
        .init(id: "1", text: "yooo this is sick", postId: "1", author: User.MOCK_USERS[0], numLikes: 2, numReplies: 2),
        .init(id: "2", text: "awesome pics guys!", postId: "1", author: User.MOCK_USERS[1], numLikes: 1, numReplies: 0),
        .init(id: "3", text: "how cool!", postId: "2", author: User.MOCK_USERS[2], numLikes: 0, numReplies: 0),
        .init(id: "4", text: "wonderful!", postId: "2", author: User.MOCK_USERS[3], numLikes: 0, numReplies: 0),
        .init(id: "5", text: "omg slayyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy", postId: "2", author: User.MOCK_USERS[5], numLikes: 0, numReplies: 0),
        .init(id: "6", text: "epic", postId: "3", author: User.MOCK_USERS[4], numLikes: 0, numReplies: 0),
        .init(id: "7", text: "the lads", postId: "3", author: User.MOCK_USERS[5], numLikes: 0, numReplies: 0)
    ]
    
}
