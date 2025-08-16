//
//  AuthenticationClientMiddleware.swift
//  Clique
//
//  Created by Rod Tavangar on 1/21/25.
//

import OpenAPIRuntime
import Foundation
import HTTPTypes

/// A client middleware that injects a value into the `Authorization` header field of the request.
struct AuthenticationMiddleware: ClientMiddleware {

    /// The value for the `Authorization` header field.
    var bearerToken: String
    
    init(_ bearerToken: String) {
        self.bearerToken = bearerToken
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(bearerToken)"
        return try await next(request, body, baseURL)
    }
}

