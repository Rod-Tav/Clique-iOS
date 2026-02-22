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
        var cloudKitZoneId: String?
        var cloudKitShareUrl: String?
        var memberCount: Int
        var flickCount: Int

        private enum CodingKeys: String, CodingKey {
            case cliqueId, cliqueName, cloudKitZoneId, cloudKitShareUrl, memberCount, flickCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            cliqueId = try container.decode(String.self, forKey: .cliqueId)
            cliqueName = try container.decode(String.self, forKey: .cliqueName)
            cloudKitZoneId = try container.decodeIfPresent(String.self, forKey: .cloudKitZoneId)
            cloudKitShareUrl = try container.decodeIfPresent(String.self, forKey: .cloudKitShareUrl)
            memberCount = max((try? container.decode(Int.self, forKey: .memberCount)) ?? 1, 1)
            flickCount = (try? container.decode(Int.self, forKey: .flickCount)) ?? 0
        }
    }

    /// Fetches the list of cloud-enabled cliques the user belongs to.
    func getCloudCliques() async throws -> [CloudCliqueInfo] {
        let url = URL(string: "\(rodSandboxURL)/cloudkit/cliques")!
        let data = try await makeRequest(url: url, method: "GET")
        return try JSONDecoder().decode([CloudCliqueInfo].self, from: data)
    }

    // MARK: - Fetching Data for Extension Views

    /// Fetches cliques the user belongs to via rod-sandbox cloud cliques endpoint.
    /// No userId needed — rod-sandbox resolves user from the auth token.
    func fetchCliques() async throws -> [CachedClique] {
        let cloudCliques = try await getCloudCliques()
        return cloudCliques.map { info in
            CachedClique(
                id: info.cliqueId,
                name: info.cliqueName,
                thumbUrl: "",
                memberCount: info.memberCount,
                flickCount: info.flickCount,
                updatedAt: Date()
            )
        }
    }

    /// Result type for collections fetch — includes both collections and extracted flicks.
    struct CollectionsResult {
        var collections: [CachedCollection]
        var flicks: [CachedFlick]
    }

    /// Fetches collections for a clique, mapped to CachedCollection.
    /// Also extracts flicks from collectionItems since there's no separate flicks-by-clique endpoint.
    func fetchCollections(for cliqueId: String) async throws -> CollectionsResult {
        let url = URL(string: "\(kotlinBackendURL)/api/v1/collection/clique/\(cliqueId)?page=0&size=50")!
        let data = try await makeRequest(url: url, method: "GET")

        struct ItemUrls: Decodable {
            var url: String?
            var medQualityUrl: String?
            var lowQualityUrl: String?
        }

        struct CollectionItemDTO: Decodable {
            var collectionItemId: String?
            var urls: ItemUrls?
            var mediaType: String?
            var dateCreated: String?
        }

        struct CollectionDataDTO: Decodable {
            var collectionDataId: String?
            var name: String?
            var clique: String?
            var dateCreated: String?
            var visibility: String?
        }

        struct CollectionDTO: Decodable {
            var collectionData: CollectionDataDTO?
            var collectionItems: [CollectionItemDTO]?
        }

        struct GetCollectionsResponse: Decodable {
            var collections: [CollectionDTO]
        }

        let response = try JSONDecoder().decode(GetCollectionsResponse.self, from: data)

        var allFlicks: [CachedFlick] = []

        let collections = response.collections.map { dto -> CachedCollection in
            let items = dto.collectionItems ?? []
            let collectionId = dto.collectionData?.collectionDataId ?? ""

            // Extract flicks from collection items
            for item in items {
                allFlicks.append(CachedFlick(
                    id: item.collectionItemId ?? UUID().uuidString,
                    thumbUrl: item.urls?.lowQualityUrl ?? item.urls?.url ?? "",
                    collectionId: collectionId,
                    mediaType: MediaType(rawValue: item.mediaType ?? "PHOTO") ?? .PHOTO,
                    createdAt: ISO8601DateFormatter().date(from: item.dateCreated ?? "") ?? Date()
                ))
            }

            // Use first item's thumbnail as collection cover
            let coverUrl = items.first?.urls?.lowQualityUrl ?? items.first?.urls?.url ?? ""

            let visibilityStr = dto.collectionData?.visibility ?? "PRIVATE"
            let visibility: Visibility = {
                switch visibilityStr {
                case "PUBLIC": return .pub
                case "FOLLOWERS": return .followers
                default: return .priv
                }
            }()

            return CachedCollection(
                id: collectionId,
                name: dto.collectionData?.name ?? "",
                thumbUrl: coverUrl,
                flickCount: items.count,
                cliqueId: cliqueId,
                visibility: visibility,
                createdAt: ISO8601DateFormatter().date(from: dto.collectionData?.dateCreated ?? "") ?? Date()
            )
        }

        return CollectionsResult(collections: collections, flicks: allFlicks)
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
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("ExtensionAPIClient: HTTP \(status) from \(url)")
            throw ExtensionError.serverError
        }

        return data
    }

    // MARK: - Cloud Clique Creation

    /// Creates a cloud-only clique via rod-sandbox.
    /// - Parameter name: Display name for the clique.
    /// - Returns: The newly created clique's ID.
    func createCloudClique(name: String) async throws -> String {
        let url = URL(string: "\(rodSandboxURL)/cloudkit/cliques")!
        let body = try JSONEncoder().encode(["name": name])
        let data = try await makeRequest(url: url, method: "POST", body: body)

        struct CreateResponse: Decodable { var id: String }
        return try JSONDecoder().decode(CreateResponse.self, from: data).id
    }

    enum ExtensionError: Error {
        case notAuthenticated
        case serverError
        case invalidResponse
    }
}
