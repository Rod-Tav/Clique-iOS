//
//  FeedService.swift
//  Clique
//
//  Created by Rod Tavangar on 7/14/24.
//

import Foundation
import FirebaseAuth
import OpenAPIURLSession

final class FeedService {
    static func fetchFeedPosts(_ input: Operations.getUserFeed.Input) async throws -> [FeedItem] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getUserFeed(input) {
        case .ok(let response):
            switch response.body {
            case .json(let feedItems):
                return mapToFeedItems(feedItems)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("register user failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func fetchFlickFeed(_ input: Operations.getInfiniteFeed.Input) async throws -> ([InfiniteFeedItem], String) {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getInfiniteFeed(input) {
        case .ok(let response):
            switch response.body {
            case .json(let items):
                return (mapToInfiniteFeedItems(items), items.encodedCursor!)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("register user failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func fetchCliqueFeed(_ input: Operations.getFeedByClique.Input) async throws -> [FeedItem] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getFeedByClique(input) {
        case .ok(let response):
            switch response.body {
            case .json(let feedItems):
                return mapToFeedItems(feedItems)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("register user failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func fetchCliqueHubFeedPosts(_ input: Operations.getCliqueHubUserFeed.Input) async throws -> [FeedItem] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCliqueHubUserFeed(input) {
        case .ok(let response):
            switch response.body {
            case .json(let feedItems):
                return mapToFeedItems(feedItems)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("register user failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}
