//
//  PaginationFetchInputs.swift
//  Clique
//
//  Created by Rod Tavangar on 1/31/25.
//

import Foundation

struct UserPaginationFetchInput {
    let uid: String
    let page: Int
    let size: Int
}

struct CliquePaginationFetchInput {
    let cid: String
    let page: Int
    let size: Int
}

struct CollectionItemsPaginationFetchInput {
    let collectionDataId: String
    let page: Int
    let size: Int
}

struct CollectionItemPaginationFetchInput {
    let imageId: String
    let page: Int
    let size: Int
}

struct SearchPaginationFetchInput {
    let query: String
    let page: Int
    let size: Int
}

struct CommentsPaginationFetchInput {
    let parentTypeId: String // flick id
    let page: Int
    let size: Int
}

struct CommentRepliesPaginationFetchInput {
    let parentId: String
    let page: Int
    let size: Int
}

struct EmptyPaginationFetchInput {
    let page: Int
    let size: Int
}
