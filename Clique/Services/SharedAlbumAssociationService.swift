//
//  SharedAlbumAssociationService.swift
//  Clique
//
//  URLSession + Firebase Bearer token client for shared album associations.
//

import Foundation
import FirebaseAuth

struct SharedAlbumAssociationService {
    private static let baseURL = "http://a1d1e6f2604554af780ebc7fc61b6e8b-2109272361.us-east-2.elb.amazonaws.com"

    struct AssociationDTO: Codable {
        let id: String
        let collectionId: String
        let albumTitle: String
        let associatedBy: String
        let associatedByUsername: String?
        let createdAt: String
        let updatedAt: String
    }

    /// Fetch association for a collection. Returns nil if not found (404).
    static func getAssociation(collectionId: String) async throws -> AssociationDTO? {
        guard let currentUser = Auth.auth().currentUser else {
            throw ServiceError.userNotAuthenticated
        }
        let token = try await currentUser.getIDToken()

        let url = URL(string: "\(baseURL)/shared-album-association/\(collectionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.somethingWentWrong
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(AssociationDTO.self, from: data)
        case 404:
            return nil
        case 401, 403:
            throw ServiceError.userNotAuthenticated
        default:
            throw ServiceError.somethingWentWrong
        }
    }

    /// Create or update association.
    static func putAssociation(collectionId: String, albumTitle: String) async throws -> AssociationDTO {
        guard let currentUser = Auth.auth().currentUser else {
            throw ServiceError.userNotAuthenticated
        }
        let token = try await currentUser.getIDToken()

        let url = URL(string: "\(baseURL)/shared-album-association")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["collectionId": collectionId, "albumTitle": albumTitle]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw ServiceError.somethingWentWrong
        }

        return try JSONDecoder().decode(AssociationDTO.self, from: data)
    }

    /// Delete association.
    static func deleteAssociation(collectionId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw ServiceError.userNotAuthenticated
        }
        let token = try await currentUser.getIDToken()

        let url = URL(string: "\(baseURL)/shared-album-association/\(collectionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw ServiceError.somethingWentWrong
        }
    }
}
