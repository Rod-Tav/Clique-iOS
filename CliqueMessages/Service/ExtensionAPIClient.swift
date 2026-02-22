//
//  ExtensionAPIClient.swift
//  CliqueMessages
//
//  Lightweight URLSession-based API client for the iMessage extension.
//  The extension cannot use the main app's OpenAPI-generated client,
//  so this provides the minimal set of endpoints needed.
//

import Foundation

class ExtensionAPIClient {
    static let shared = ExtensionAPIClient()

    // Base URLs matching the main app's backend configuration.
    // The Kotlin backend handles clique creation; rod-sandbox handles CloudKit zone registration.
    private let kotlinBackendURL = "http://accbf7e7599704f989a582ebfcf59ca4-1759478004.us-east-2.elb.amazonaws.com:8080"
    private let rodSandboxURL = "http://a1d1e6f2604554af780ebc7fc61b6e8b-2109272361.us-east-2.elb.amazonaws.com"

    init() {}

    // MARK: - Clique Creation

    /// Creates a new clique on the Kotlin backend.
    /// - Parameter name: Display name for the clique.
    /// - Returns: The newly created clique's ID.
    func createClique(name: String) async throws -> String {
        let url = URL(string: "\(kotlinBackendURL)/api/v1/cliques")!
        let body = try JSONEncoder().encode(["name": name])
        let data = try await makeRequest(url: url, method: "POST", body: body)

        struct CreateCliqueResponse: Decodable {
            var id: String
        }
        let response = try JSONDecoder().decode(CreateCliqueResponse.self, from: data)
        return response.id
    }

    // MARK: - CloudKit Zone Registration

    /// Registers a CloudKit shared zone for a clique on the rod-sandbox service.
    func setCloudKitZone(cliqueId: String, zoneId: String, shareUrl: String) async throws {
        let url = URL(string: "\(rodSandboxURL)/cloudkit/zone")!
        let payload: [String: String] = [
            "cliqueId": cliqueId,
            "zoneId": zoneId,
            "shareUrl": shareUrl
        ]
        let body = try JSONEncoder().encode(payload)
        _ = try await makeRequest(url: url, method: "PUT", body: body)
    }

    // MARK: - Cloud Clique Listing

    struct CloudCliqueInfo: Codable {
        var cliqueId: String
        var cliqueName: String
        var cloudKitZoneId: String
        var cloudKitShareUrl: String?
        var memberCount: Int
    }

    /// Fetches the list of cloud-enabled cliques the user belongs to.
    func getCloudCliques() async throws -> [CloudCliqueInfo] {
        let url = URL(string: "\(rodSandboxURL)/cloudkit/cliques")!
        let data = try await makeRequest(url: url, method: "GET")
        return try JSONDecoder().decode([CloudCliqueInfo].self, from: data)
    }

    // MARK: - Fetching Data for Extension Views

    /// Fetches cliques the user belongs to, mapped to CachedClique.
    func fetchCliques() async throws -> [CachedClique] {
        let url = URL(string: "\(kotlinBackendURL)/api/v1/cliques/mine")!
        let data = try await makeRequest(url: url, method: "GET")

        struct CliqueDTO: Decodable {
            var id: String
            var name: String
            var profilePictureUrl: String?
            var memberCount: Int?
            var flickCount: Int?
            var updatedAt: String?
        }

        let dtos = try JSONDecoder().decode([CliqueDTO].self, from: data)
        return dtos.map { dto in
            CachedClique(
                id: dto.id,
                name: dto.name,
                thumbUrl: dto.profilePictureUrl ?? "",
                memberCount: dto.memberCount ?? 0,
                flickCount: dto.flickCount ?? 0,
                updatedAt: ISO8601DateFormatter().date(from: dto.updatedAt ?? "") ?? Date()
            )
        }
    }

    /// Fetches collections for a clique, mapped to CachedCollection.
    func fetchCollections(for cliqueId: String) async throws -> [CachedCollection] {
        let url = URL(string: "\(kotlinBackendURL)/api/v1/cliques/\(cliqueId)/collections?page=0&size=50")!
        let data = try await makeRequest(url: url, method: "GET")

        struct CollectionDTO: Decodable {
            var id: String
            var name: String
            var coverPhotoUrl: String?
            var flickCount: Int?
            var createdAt: String?
        }

        let dtos = try JSONDecoder().decode([CollectionDTO].self, from: data)
        return dtos.map { dto in
            CachedCollection(
                id: dto.id,
                name: dto.name,
                thumbUrl: dto.coverPhotoUrl ?? "",
                flickCount: dto.flickCount ?? 0,
                cliqueId: cliqueId,
                createdAt: ISO8601DateFormatter().date(from: dto.createdAt ?? "") ?? Date()
            )
        }
    }

    /// Fetches flicks for a clique, mapped to CachedFlick.
    func fetchFlicks(for cliqueId: String) async throws -> [CachedFlick] {
        let url = URL(string: "\(kotlinBackendURL)/api/v1/cliques/\(cliqueId)/flicks?page=0&size=50")!
        let data = try await makeRequest(url: url, method: "GET")

        struct FlickDTO: Decodable {
            var id: String
            var thumbnailUrl: String?
            var collectionId: String?
            var mediaType: String?
            var createdAt: String?
        }

        let dtos = try JSONDecoder().decode([FlickDTO].self, from: data)
        return dtos.map { dto in
            CachedFlick(
                id: dto.id,
                thumbUrl: dto.thumbnailUrl ?? "",
                collectionId: dto.collectionId ?? "",
                mediaType: MediaType(rawValue: dto.mediaType ?? "PHOTO") ?? .PHOTO,
                createdAt: ISO8601DateFormatter().date(from: dto.createdAt ?? "") ?? Date()
            )
        }
    }

    // MARK: - Networking

    private func makeRequest(url: URL, method: String, body: Data? = nil) async throws -> Data {
        guard let token = ExtensionAuthManager.shared.getAuthToken() else {
            throw ExtensionError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ExtensionError.serverError
        }

        return data
    }

    enum ExtensionError: Error {
        case notAuthenticated
        case serverError
        case invalidResponse
    }
}
