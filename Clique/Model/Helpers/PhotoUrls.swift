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

    /// Initialize with URLs for each quality level
    init(url: String? = nil, medQualityUrl: String? = nil, lowQualityUrl: String? = nil) {
        self.url = url
        self.medQualityUrl = medQualityUrl
        self.lowQualityUrl = lowQualityUrl
    }

    /// Legacy initializer for backward compatibility
    init(highQualityUrl: String? = nil, medQualityUrl: String? = nil, lowQualityUrl: String? = nil) {
        self.url = highQualityUrl
        self.medQualityUrl = medQualityUrl
        self.lowQualityUrl = lowQualityUrl
    }

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

    /// Get URL specifically for videos - prioritizes backend-processed versions over original upload
    ///
    /// Unlike `url(for:)` which prioritizes the original upload, this method prioritizes
    /// backend-processed versions (720p/360p) which have proper streaming optimization
    /// via ffmpeg's `-movflags +faststart`. This ensures videos play correctly in AVPlayer.
    ///
    /// - Parameter quality: The desired quality level
    /// - Returns: URL prioritizing backend-processed (medium/low) over original
    func videoUrl(for quality: ImageQuality) -> URL? {
        switch quality {
        case .high:
            // For videos: backend-processed medium > low > original
            // Backend creates 720p/360p with proper streaming flags
            return URL(string: medQualityUrl ?? "")
                ?? URL(string: lowQualityUrl ?? "")
                ?? URL(string: url ?? "")
        case .medium:
            return URL(string: medQualityUrl ?? "") ?? URL(string: lowQualityUrl ?? "")
        case .low:
            return URL(string: lowQualityUrl ?? "")
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
