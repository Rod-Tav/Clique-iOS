//
//  CliqueService.swift
//  Clique
//
//  Created by Rod Tavangar on 6/13/24.
//

import Foundation
import FirebaseAuth

// MARK: - Members
class CliqueService {
    /// Returns leader first
    static func getCliqueMembers(_ input: Operations.getCliqueMembers.Input) async throws -> [User] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCliqueMembers(input) {
        case .ok(let response):
            switch response.body {
            case .json(let users):
                return mapToUsers(users)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get clique members failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func getCliqueRelationship(_ input: Operations.getCliqueMemberStatus.Input) async throws -> CliqueRelationship {
//        print("getting clique relationship")
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCliqueMemberStatus(input) {
        case .ok(let response):
            switch response.body {
            case .json(let status):
                return mapToCliqueRelationship(status)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get member status failed")
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Create and edit
extension CliqueService {
    static func createClique(_ input: Operations.createClique.Input) async throws -> Clique {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.createClique(input){
        case .ok(let response):
            switch response.body {
            case .json(let clique):
                let clique = mapToClique(clique)
                
                if case let .json(requestBody) = input.body {
                    let memberCount = (requestBody.members?.count ?? 0) + 1
                    
                    track(
                        event: "Clique Created",
                        properties: [
                            "cliqueId": clique.id,
                            "numMembers": memberCount
                        ]
                    )
                }

                return clique
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: create clique failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func editClique(_ input: Operations.editClique.Input) async throws -> Clique {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.editClique(input) {
        case .ok(let response):
            switch response.body {
            case .json(let clique):
                return mapToClique(clique)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: edit clique failed")
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func blockClique(_ input: Operations.blockClique.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.blockClique(input) {
        case .ok:
            return
        default:
            throw ServiceError.somethingWentWrong
        }
    }
}

// MARK: - Get Clique
extension CliqueService {
    static func getCliqueById(id: String) async throws -> Clique {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getClique(path: .init(cliqueId: id)) {
        case .ok(let response):
            switch response.body {
            case .json(let clique):
                return mapToClique(clique)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get clique by id failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
    
    static func getUserCliques(_ input: Operations.getCliquesByUser.Input) async throws -> [Clique] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCliquesByUser(input) {
        case .ok(let response):
            switch response.body {
            case .json(let cliques):
                return mapToCliques(cliques)
            }
        case .badRequest(let error):
            print(error)
        case .internalServerError(let error):
            print(error)
        default:
            print("DEBUG: get user cliques failed")
            throw ServiceError.somethingWentWrong
        }
        throw ServiceError.somethingWentWrong
    }
}

// MARK: - Invites
extension CliqueService {
    static func inviteUsers(_ input: Operations.inviteToClique.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.inviteToClique(input) {
        case .ok:
            return
        default:
            print("DEBUG: invite users failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func getCliqueInvites(_ input: Operations.getCliqueInvites.Input) async throws -> [Components.Schemas.CliqueInvite] {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.getCliqueInvites(input) {
        case .ok(let response):
            switch response.body {
            case .json(let invites):
                return invites.invites!
            }
        default:
            print("DEBUG: get clique invites failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func acceptCliqueInvite(_ input: Operations.acceptInvite.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.acceptInvite(input) {
        case .ok:
            return
        default:
            print("DEBUG: accept clique invite failed")
            throw ServiceError.somethingWentWrong
        }
    }
    
    static func declineCliqueInvite(_ input: Operations.declineInvite.Input) async throws {
        let client = try await ClientManager.shared.createClient()
        
        switch try await client.declineInvite(input) {
        case .ok:
            return
        default:
            print("DEBUG: accept clique invite failed")
            throw ServiceError.somethingWentWrong
        }
    }
}

// MARK: - Profile
//extension CliqueService {
//    static func fetchCliqueCollections(id: String) -> [ClCollection] {
//        switch id {
//        case "1":
//            return []
//        case "2":
//            return []
//        case "3":
//            return []
//        case "4":
//            return []
//        case "5": // huddle
//            return [ClCollection.MOCK_COLLECTIONS[0]]
//        case "6": // t_olympics
//            return [ClCollection.MOCK_COLLECTIONS[2], ClCollection.MOCK_COLLECTIONS[1]]
//        default:
//            return []
//        }
//    }
//}
