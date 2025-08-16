//
//  DeepLinkManager.swift
//  Clique
//
//  Created by Rod Tavangar on 2/6/25.
//

import Foundation

// this will be used to navigate the user to a specific screen when they tap a push notification banner
class DeepLinkManager {
    enum DeeplinkTarget: Equatable {
        case home
        case details(reference: String)
    }
    
    class DeepLinkConstants {
        static let scheme = "clique"
        static let host = "com.cliqueapp"
        static let detailsPath = "/details"
        static let query = "id"
    }
    
    func manage(_ url: URL) -> DeeplinkTarget {
        guard url.scheme == DeepLinkConstants.scheme,
              url.host == DeepLinkConstants.host,
              url.path == DeepLinkConstants.detailsPath,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems
        else { return .home }
        
        let query = queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
        
        guard let id = query[DeepLinkConstants.query] else { return .home }
        
        return .details(reference: id)
    }
}
