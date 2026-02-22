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
}

@available(iOS 26, *)
struct CloudCliqueService {
    private static let baseURL = "https://flicks.cliquemobile.app"

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
