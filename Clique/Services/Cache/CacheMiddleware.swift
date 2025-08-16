//
//  CacheMiddleware.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import OpenAPIRuntime
import Foundation
import HTTPTypes

struct CacheMiddleware: ClientMiddleware {
    private let cacheManager = CacheManager.shared
    
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        
        let path = request.path ?? ""
        let method = request.method
        
        guard CachePolicy.shouldCache(method: method, path: path) else {
            let result = try await next(request, body, baseURL)
            
            await handleInvalidation(method: method, path: path)
            
            return result
        }
        
        var bodyData: Data? = nil
        if let body = body {
            bodyData = try await Data(collecting: body, upTo: 10 * 1024 * 1024)
        }
        
        let cacheKey = await cacheManager.createCacheKey(from: request, body: bodyData)
        
        if let cachedData = await cacheManager.get(key: cacheKey) {
            let response = HTTPResponse(status: .ok)
            let cachedBody = HTTPBody(cachedData)
            return (response, cachedBody)
        }
        
        let recreatedBody = bodyData.map { HTTPBody($0) }
        let (response, responseBody) = try await next(request, recreatedBody, baseURL)
        
        if response.status == .ok, let responseBody = responseBody {
            let responseData = try await Data(collecting: responseBody, upTo: 10 * 1024 * 1024)
            
            if let ttl = CachePolicy.getTTL(for: path, method: method) {
                let etag = response.headerFields[.eTag]
                await cacheManager.set(key: cacheKey, value: responseData, ttl: ttl, etag: etag)
            }
            
            return (response, HTTPBody(responseData))
        }
        
        return (response, responseBody)
    }
    
    private func handleInvalidation(method: HTTPRequest.Method, path: String) async {
        let patterns = CachePolicy.getInvalidationPatterns(for: path, method: method)
        if !patterns.isEmpty {
            await cacheManager.invalidate(patterns: patterns)
        }
    }
}