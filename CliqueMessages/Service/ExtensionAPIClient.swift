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
    private let rodSandboxURL = "https://flicks.cliquemobile.app"

    private init() {}

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
