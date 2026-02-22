//
//  CachedModels.swift
//  CliqueMessages
//
//  Lightweight cached data models for the iMessage extension.
//

import Foundation

struct CachedClique: Codable, Identifiable {
    var id: String
    var name: String
    var thumbUrl: String
    var memberCount: Int
    var flickCount: Int
    var updatedAt: Date = Date()
}

enum Visibility: String, Codable {
    case pub = "PUBLIC"
    case followers = "FOLLOWERS"
    case priv = "PRIVATE"
}

struct CachedCollection: Codable, Identifiable {
    var id: String
    var name: String
    var thumbUrl: String
    var flickCount: Int
    var cliqueId: String
    var visibility: Visibility = .priv
    var createdAt: Date = Date()
}

enum MediaType: String, Codable {
    case PHOTO
    case VIDEO
    case LIVE
}

struct CachedFlick: Codable, Identifiable {
    var id: String
    var thumbUrl: String
    var collectionId: String
    var mediaType: MediaType
    var createdAt: Date = Date()
}

struct CachedUser: Codable {
    var id: String
    var username: String
}
