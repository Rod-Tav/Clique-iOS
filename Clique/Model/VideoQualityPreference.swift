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
/// ## Auto Mode Intelligence
/// When set to `.auto`, quality adapts based on network conditions:
/// - **Low Data Mode ON**: Uses low quality (respects user data saving preference)
/// - **Expensive connection** (roaming, hotspot, metered): Uses medium quality
/// - **WiFi/Ethernet**: Uses high quality
/// - **Cellular**: Uses medium quality (safe default for most data plans)
///
/// ## Usage
/// ```swift
/// @AppStorage("videoQualityPreference") private var videoQualityPreference: VideoQualityPreference = .auto
///
/// // Get quality with network adaptation
/// let quality = videoQualityPreference.imageQuality
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

    /// Returns the appropriate `ImageQuality` based on preference and network conditions
    ///
    /// For `.auto` mode, consults `NetworkMonitor` to intelligently select quality based on:
    /// - Low Data Mode setting
    /// - Connection cost (expensive/metered)
    /// - Connection type (WiFi/cellular/ethernet)
    ///
    /// - Returns: The recommended quality level for current conditions
    var imageQuality: ImageQuality {
        switch self {
        case .auto:
            // Use network-aware quality recommendation
            return NetworkMonitor.shared.recommendedVideoQuality()
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        }
    }
}
