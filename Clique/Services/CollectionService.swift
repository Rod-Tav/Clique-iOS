//
//  CollectionService.swift
//  Clique
//
//  Created by Rod Tavangar on 7/12/24.
//

import Foundation
import OpenAPIURLSession

// MARK: - Get
struct CollectionService {
    static func getCollectionsByUser(_ input: Operations.getCollectionsByUser.Input) async throws -> [ClCollection] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCollectionsByUser(input) {
        case .ok(let response):
            switch response.body {
            case .json(let collections):
                return mapToCollections(collections)
            }
        default:
            print("DEBUG: get collections by user failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func getCollectionsByClique(_ input: Operations.getCollectionsByClique.Input) async throws -> [ClCollection] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCollectionsByClique(input) {
        case .ok(let response):
            switch response.body {
            case .json(let collections):
                return mapToCollections(collections)
            }
        default:
            print("DEBUG: get collections by cliques failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func getCollectionById(_ input: Operations.getCollectionById.Input) async throws -> ClCollection {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCollectionById(input) {
        case .ok(let response):
            switch response.body {
            case .json(let collection):
                return mapToCollection(collection)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get collection by id failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Edit
extension CollectionService {
    static func editCollection(_ input: Operations.editCollection.Input) async throws -> ClCollection {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.editCollection(input) {
        case .ok(let response):
            switch response.body {
            case .json(let collection):
                return mapToCollection(collection)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: edit collection failed")
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Interact
extension CollectionService {
    static func likeCollectionItem(_ input: Operations.likeCollectionItem.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.likeCollectionItem(input) {
        case .ok:
            track(
                event: "Liked Flick",
                properties: [
                    "flickId": input.path.collectionItemId
                ]
            )
            
            return
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: like collection item failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func unlikeCollectionItem(_ input: Operations.unlikeCollectionItem.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.unlikeCollectionItem(input) {
        case .ok:
            track(
                event: "Unliked Flick",
                properties: [
                    "flickId": input.path.collectionItemId
                ]
            )
            
            return
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: unlike collection item failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func getLiked(_ input: Operations.getCollectionItemLikedBy.Input) async throws -> [User] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCollectionItemLikedBy(input) {
        case .ok(let response):
            switch response.body {
            case .json(let users):
                return mapToUsers(users)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        case .undocumented(statusCode: let statusCode, _):
            print(statusCode)
        default:
            print("DEBUG: get collection item liked by failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Delete
extension CollectionService {
    static func deleteCollection(_ input: Operations.deleteCollection.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.deleteCollection(input) {
        case .ok:
            track(
                event: "Deleted Collection",
                properties: [
                    "collectionId": input.path.collectionDataId
                ]
            )
            
            return
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: delete collection failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func deleteCollectionItem(_ input: Operations.deleteCollectionItem.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.deleteCollectionItem(input) {
        case .ok:
            return
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: delete collection item failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Create
extension CollectionService {
    static func createCollection(_ input: Operations.createCollection.Input) async throws -> Components.Schemas.CollectionResponseBody {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.createCollection(input) {
        case .ok(let response):
            switch response.body {
            case .json(let collectionResponseBody):
                let collection = mapToCollection(collectionResponseBody)
                
                track(
                    event: "Collection Created",
                    properties: [
                        "collectionId": collection.id,
                        "cliqueId": collection.cliqueId,
                        "visibility": collection.visibility.rawValue
                    ]
                )
                
                return collectionResponseBody
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: create collection failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func uploadPhotosToCollection(_ input: Operations.uploadCollectionItems.Input) async throws -> Components.Schemas.CollectionResponseBody {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.uploadCollectionItems(input) {
        case .ok(let response):
            switch response.body {
            case .json(let collectionResponseBody):
                let collection = mapToCollection(collectionResponseBody)
                
                if case let .json(requestBody) = input.body {
                    track(
                        event: "Upload Flicks",
                        properties: [
                            "collectionId": collection.id,
                            "cliqueId": collection.cliqueId,
                            "visibility": collection.visibility.rawValue,
                            "numFlicks": requestBody.photos?.count
                        ]
                    )
                }
                
                return collectionResponseBody
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: upload photos to collection failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func markCollectionImagesAsUploaded(_ input: Operations.markCollectionItemsUploaded.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.markCollectionItemsUploaded(input) {
        case .ok:
            return
        default:
            print("DEBUG: mark collection items as upload failed")
            throw ServiceError.somethingWentWrong
        }
    }
}
