//
//  VideoQualityPreference.swift
//  Clique
//
//  Created by Assistant on Video quality preference implementation.
//

import Foundation

/// Video quality preference for playback control
///
/// Controls video quality selection for network video playback throughout the app.
/// Persisted using `@AppStorage("videoQualityPreference")` for consistent experience.
///
/// ## Usage
/// ```swift
/// @AppStorage("videoQualityPreference") private var videoQualityPreference: VideoQualityPreference = .auto
/// ```
enum VideoQualityPreference: String, CaseIterable, Codable {
    case auto = "auto"
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .high: return "High Quality"
        case .medium: return "Medium Quality"
        case .low: return "Low Quality"
        }
    }

    var imageQuality: ImageQuality {
        switch self {
        case .auto, .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}
