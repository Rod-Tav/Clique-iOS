//
//  PhotoUrls.swift (transitioning to MediaUrls)
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//  Updated by Claude on 1/31/25 for Live Photos and Videos support
//

import Foundation

/// Represents URLs for different quality variants of media (photo or video)
struct MediaUrls: Codable, Hashable, Sendable {
    /// Full resolution URL
    var url: String?
    /// Medium quality URL (for feed display)
    var medQualityUrl: String?
    /// Low quality/thumbnail URL (for grid views)
    var lowQualityUrl: String?

    /// All quality levels in fallback order (high → medium → low)
    var urls: [String?] {
        [url, medQualityUrl, lowQualityUrl]
    }

    /// All valid, non-nil URLs in fallback order
    var validUrls: [URL] {
        urls
            .compactMap { $0 }
            .compactMap(URL.init)
    }

    /// Best available URL (first non-nil in quality order)
    var bestUrl: URL? {
        validUrls.first
    }

    /// Get URL for specific quality with fallback down to lower qualities
    func url(for quality: ImageQuality) -> URL? {
        switch quality {
        case .high:
            return validUrls.first
        case .medium:
            return URL(string: medQualityUrl ?? "") ?? URL(string: lowQualityUrl ?? "")
        case .low:
            return URL(string: lowQualityUrl ?? "")
        }
    }

    /// Get URL for videos with network-adaptive quality selection
    ///
    /// Automatically adjusts quality based on network connection:
    /// - **WiFi/Ethernet**: Prioritizes quality (original → med → low)
    /// - **Cellular**: Prioritizes data savings (med → low → original)
    ///
    /// - Parameter quality: The desired quality level
    /// - Returns: URL with network-adaptive fallback logic
    func videoUrl(for quality: ImageQuality) -> URL? {
        let networkMonitor = NetworkMonitor.shared
        let prefersHighQuality = networkMonitor.connectionType.prefersHighQuality

        switch quality {
        case .high:
            if prefersHighQuality {
                // WiFi: Try original first (best quality)
                return URL(string: url ?? "")
                    ?? URL(string: medQualityUrl ?? "")
                    ?? URL(string: lowQualityUrl ?? "")
            } else {
                // Cellular: Try processed version first (data savings)
                return URL(string: medQualityUrl ?? "")
                    ?? URL(string: lowQualityUrl ?? "")
                    ?? URL(string: url ?? "")
            }
        case .medium:
            // Always prefer med quality for medium request
            return URL(string: medQualityUrl ?? "")
                ?? URL(string: lowQualityUrl ?? "")
                ?? URL(string: url ?? "")
        case .low:
            // Always prefer low quality for low request
            return URL(string: lowQualityUrl ?? "")
                ?? URL(string: medQualityUrl ?? "")
                ?? URL(string: url ?? "")
        }
    }

    /// Get URL for videos with manual quality override (for detail view quality selector)
    /// - Parameter quality: Specific quality level to fetch
    /// - Parameter forceQuality: If true, only returns the exact quality requested (no fallback)
    /// - Returns: URL for specified quality
    func videoUrl(for quality: ImageQuality, forceQuality: Bool) -> URL? {
        if forceQuality {
            // Return exact quality requested, no fallback
            switch quality {
            case .high:
                return URL(string: url ?? "")
            case .medium:
                return URL(string: medQualityUrl ?? "")
            case .low:
                return URL(string: lowQualityUrl ?? "")
            }
        } else {
            // Use network-adaptive logic
            return videoUrl(for: quality)
        }
    }

    /// Legacy property for backward compatibility
    var highQualityUrl: String? {
        get { url }
        set { url = newValue }
    }
}

/// Backward compatibility typealias - will be removed after full migration
typealias PhotoUrls = MediaUrls
