import Foundation
import FirebaseAuth

struct UserFlicksService {
    // TODO: Replace with your actual Load Balancer URL from kubectl get svc
    // Run: kubectl get svc user-flicks-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    private static let baseURL = "http://REPLACE_WITH_YOUR_LB_URL"

    struct UserFlicksResponse: Codable {
        let flicks: [UserFlickDTO]
        let page: Int
        let size: Int
        let hasMore: Bool
        let total: Int
    }

    struct UserFlickDTO: Codable {
        let collectionItemId: String
        let dateCreated: String
        let uploadStatus: Int
        let mediaType: Int
        let commentCount: Int
        let userId: String
        let username: String
        let firstName: String
        let lastName: String
        let bio: String?
        let photoId: String?
        let photoPath: String?
        let photoMedPath: String?
        let photoLowPath: String?
        let videoId: String?
        let videoPath: String?
        let videoMedPath: String?
        let videoLowPath: String?
        let collectionId: String
        let collectionName: String
        let collectionDescription: String?
        let cliqueId: String
        let likeTotal: Int
    }

    static func getUserFlicks(page: Int, size: Int) async throws -> UserFlicksResponse {
        guard let currentUser = Auth.auth().currentUser else {
            throw ServiceError.userNotAuthenticated
        }

        // Get Firebase ID token
        let token = try await currentUser.getIDToken()

        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/user-flicks")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ]

        guard let url = components.url else {
            throw ServiceError.invalidURL
        }

        // Create request with auth header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(UserFlicksResponse.self, from: data)
        case 401, 403:
            throw ServiceError.userNotAuthenticated
        case 400:
            throw ServiceError.badRequest
        default:
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
