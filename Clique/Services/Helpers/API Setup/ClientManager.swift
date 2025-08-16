//
//  ClientManager.swift
//  Clique
//
//  Created by Rod Tavangar on 1/28/25.
//

import FirebaseAuth
import OpenAPIRuntime
import OpenAPIURLSession

class ClientManager {
    static let shared = ClientManager()
    
    private var client: Client?
    private var currentToken: String?
    
    private init() {}
    
    func createClient() async throws -> Client {
        guard let currentUser = Auth.auth().currentUser else {
            throw ServiceError.userNotAuthenticated
        }
        
        let token = try await currentUser.getIDToken()
        
        if client == nil || currentToken != token {
            currentToken = token
            client = Client(
                serverURL: AppConfig.serverURL,
                transport: URLSessionTransport(),
                middlewares: [
                    CacheMiddleware(),
                    AuthenticationMiddleware(token)
                ]
            )
        }
        
        return client!
    }
}
