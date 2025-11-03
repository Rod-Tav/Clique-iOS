//
//  MediaType.swift
//  Clique
//
//  Created by Claude on 1/31/25.
//

import Foundation

/// Media type enum matching backend schema
enum MediaType: String, Codable, Hashable, Sendable {
    case PHOTO
    case LIVE
    case VIDEO

    var displayName: String {
        switch self {
        case .PHOTO: return "Photo"
        case .LIVE: return "Live Photo"
        case .VIDEO: return "Video"
        }
    }

    var iconName: String {
        switch self {
        case .PHOTO: return "photo"
        case .LIVE: return "livephoto"
        case .VIDEO: return "video.fill"
        }
    }
}