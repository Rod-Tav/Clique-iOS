import Foundation
import FirebaseAuth

struct UserFlicksService {
    /// Production load balancer URL for rod-sandbox microservice
    private static let baseURL = "http://a1d1e6f2604554af780ebc7fc61b6e8b-2109272361.us-east-2.elb.amazonaws.com"

    struct UserFlicksResponse: Codable {
        let flicks: [UserFlickDTO]
        let page: Int
        let size: Int
        let hasMore: Bool
        let total: Int
    }

    struct UserFlickDTO: Codable, Identifiable {
        let collectionItemId: String
        let dateCreated: String
        let dateUploaded: String?
        let uploaded: Bool?
        let uploadStatus: Int?
        let mediaType: Int?
        let commentCount: Int?
        let likeCountId: String?
        let userId: String
        let username: String?
        let firstName: String?
        let lastName: String?
        let bio: String?
        let firebaseId: String?
        let isPrivate: Bool?
        let followersCount: Int?
        let followingCount: Int?
        let photoId: String?
        let photoPath: String?
        let photoMedPath: String?
        let photoLowPath: String?
        let videoId: String?
        let videoPath: String?
        let videoMedPath: String?
        let videoLowPath: String?
        let collectionId: String?
        let collectionName: String?
        let collectionDescription: String?
        let privacySetting: String?
        let cliqueId: String?
        let likeTotal: Int?

        var id: String { collectionItemId }

        /// Get MediaUrls for the photo (used for grid display)
        var photoUrls: MediaUrls? {
            guard photoPath != nil || photoMedPath != nil || photoLowPath != nil else {
                return nil
            }
            return MediaUrls(
                url: photoPath,
                medQualityUrl: photoMedPath,
                lowQualityUrl: photoLowPath
            )
        }
    }

    static func getUserFlicks(page: Int, size: Int) async throws -> UserFlicksResponse {
        print("🔵 [UserFlicksService] Starting getUserFlicks - page: \(page), size: \(size)")

        guard let currentUser = Auth.auth().currentUser else {
            print("🔴 [UserFlicksService] No current user - not authenticated")
            throw ServiceError.userNotAuthenticated
        }
        print("🟢 [UserFlicksService] Current user ID: \(currentUser.uid)")

        // Get Firebase ID token
        let token: String
        do {
            token = try await currentUser.getIDToken()
            print("🟢 [UserFlicksService] Got Firebase token (length: \(token.count))")
        } catch {
            print("🔴 [UserFlicksService] Failed to get token: \(error)")
            throw error
        }

        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/user-flicks")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ]

        guard let url = components.url else {
            print("🔴 [UserFlicksService] Invalid URL")
            throw ServiceError.invalidURL
        }
        print("🔵 [UserFlicksService] Request URL: \(url.absoluteString)")

        // Create request with auth header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Make request
        let data: Data
        let response: URLResponse
        do {
            print("🔵 [UserFlicksService] Making network request...")
            (data, response) = try await URLSession.shared.data(for: request)
            print("🟢 [UserFlicksService] Received response - data size: \(data.count) bytes")
        } catch {
            print("🔴 [UserFlicksService] Network error: \(error)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 [UserFlicksService] Invalid response type")
            throw ServiceError.invalidResponse
        }
        print("🔵 [UserFlicksService] HTTP Status Code: \(httpResponse.statusCode)")

        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔵 [UserFlicksService] Raw response: \(responseString.prefix(500))...")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(UserFlicksResponse.self, from: data)
                print("🟢 [UserFlicksService] Successfully decoded - \(result.flicks.count) flicks, hasMore: \(result.hasMore)")
                return result
            } catch {
                print("🔴 [UserFlicksService] Decoding error: \(error)")
                throw error
            }
        case 401, 403:
            print("🔴 [UserFlicksService] Auth error - status \(httpResponse.statusCode)")
            throw ServiceError.userNotAuthenticated
        case 400:
            print("🔴 [UserFlicksService] Bad request - status 400")
            throw ServiceError.badRequest
        default:
            print("🔴 [UserFlicksService] Unexpected status code: \(httpResponse.statusCode)")
            throw ServiceError.somethingWentWrong
        }
    }
}

// Add to ServiceError if not already present
extension ServiceError {
    static let invalidURL = ServiceError.somethingWentWrong
    static let badRequest = ServiceError.somethingWentWrong
    static let invalidResponse = ServiceError.somethingWentWrong
}
