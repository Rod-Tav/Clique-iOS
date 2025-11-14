//
//  DeepLinkManager.swift
//  Clique
//
//  Created by Rod Tavangar on 2/6/25.
//

import Foundation

// this will be used to navigate the user to a specific screen when they tap a push notification banner or deep link
class DeepLinkManager {
    enum DeeplinkTarget: Equatable {
        case home
        case details(reference: String)
        case collection(id: String)
    }

    class DeepLinkConstants {
        static let scheme = "clique"
    }

    /// Parses a deep link URL and returns the appropriate target
    /// - Parameter url: The URL to parse (format: clique://collection/{id})
    /// - Returns: The parsed deep link target
    func manage(_ url: URL) -> DeeplinkTarget {
        // Verify scheme
        guard url.scheme == DeepLinkConstants.scheme else {
            return .home
        }

        // In clique://collection/abc-123, "collection" is the host, not the path
        guard let host = url.host else {
            return .home
        }

        // Extract the ID from the path (remove leading "/")
        let path = url.path
        let id = String(path.dropFirst()) // Remove the leading "/"

        guard !id.isEmpty else {
            return .home
        }

        // Route based on host (resource type)
        switch host {
        case "collection":
            return .collection(id: id)
        case "details":
            return .details(reference: id)
        default:
            return .home
        }
    }
}
