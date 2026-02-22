//
//  CloudCliqueService.swift
//  Clique
//
//  Lightweight URLSession client for Cloud Clique endpoints.
//

import Foundation

@available(iOS 26, *)
struct CloudCliqueInfo: Codable {
    var cliqueId: String
    var cliqueName: String
    var cloudKitZoneId: String?
    var cloudKitShareUrl: String?
    var memberCount: Int
    var linkedAlbumTitle: String?
    var linkedAlbumTitles: [String]?

    private enum CodingKeys: String, CodingKey {
        case cliqueId, cliqueName, cloudKitZoneId, cloudKitShareUrl
        case memberCount, linkedAlbumTitle, linkedAlbumTitles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cliqueId = try container.decode(String.self, forKey: .cliqueId)
        cliqueName = try container.decode(String.self, forKey: .cliqueName)
        cloudKitZoneId = try container.decodeIfPresent(String.self, forKey: .cloudKitZoneId)
        cloudKitShareUrl = try container.decodeIfPresent(String.self, forKey: .cloudKitShareUrl)
        memberCount = max((try? container.decode(Int.self, forKey: .memberCount)) ?? 1, 1)
        linkedAlbumTitle = try container.decodeIfPresent(String.self, forKey: .linkedAlbumTitle)
        linkedAlbumTitles = try container.decodeIfPresent([String].self, forKey: .linkedAlbumTitles)
    }

    var albumTitles: [String] {
        if let titles = linkedAlbumTitles, !titles.isEmpty { return titles }
        if let single = linkedAlbumTitle { return [single] }
        return []
    }
}

@available(iOS 26, *)
struct CloudCliqueService {
    private static let baseURL = "http://a1d1e6f2604554af780ebc7fc61b6e8b-2109272361.us-east-2.elb.amazonaws.com"

    enum ServiceError: Error {
        case notAuthenticated
        case serverError(Int)
        case invalidResponse
    }

    static func fetchCloudCliques() async throws -> [CloudCliqueInfo] {
        let data = try await makeRequest(url: URL(string: "\(baseURL)/cloudkit/cliques")!, method: "GET")
        return try JSONDecoder().decode([CloudCliqueInfo].self, from: data)
    }

    static func linkAlbum(cliqueId: String, albumTitle: String) async throws {
        let url = URL(string: "\(baseURL)/cloudkit/cliques/\(cliqueId)/album")!
        let body = try JSONEncoder().encode(["albumTitle": albumTitle])
        _ = try await makeRequest(url: url, method: "PUT", body: body)
    }

    /// Creates a cloud-only clique on rod-sandbox with an optional album link. Returns the new clique ID.
    static func createCloudClique(name: String, albumTitle: String? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/cloudkit/cliques")!
        var payload: [String: String] = ["name": name]
        if let albumTitle { payload["albumTitle"] = albumTitle }
        let body = try JSONEncoder().encode(payload)
        let data = try await makeRequest(url: url, method: "POST", body: body)

        struct CreateResponse: Decodable { var id: String }
        return try JSONDecoder().decode(CreateResponse.self, from: data).id
    }

    static func unlinkAlbum(cliqueId: String) async throws {
        let url = URL(string: "\(baseURL)/cloudkit/cliques/\(cliqueId)/album")!
        let body = try JSONSerialization.data(withJSONObject: ["albumTitle": NSNull()])
        _ = try await makeRequest(url: url, method: "PUT", body: body)
    }

    static func unlinkAlbum(cliqueId: String, albumTitle: String) async throws {
        let encoded = albumTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? albumTitle
        let url = URL(string: "\(baseURL)/cloudkit/cliques/\(cliqueId)/albums/\(encoded)")!
        _ = try await makeRequest(url: url, method: "DELETE")
    }

    private static func makeRequest(url: URL, method: String, body: Data? = nil) async throws -> Data {
        guard let token = SharedAuthState.load()?.firebaseToken else {
            throw ServiceError.notAuthenticated
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ServiceError.serverError(code)
        }
        return data
    }
}
