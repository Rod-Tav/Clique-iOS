//
//  DataStoreHelper.swift
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//

import Foundation

func shouldUpdatePhotoUrls(_ old: PhotoUrls?, _ new: PhotoUrls?, threshold: TimeInterval = 3600) -> Bool {
    guard let old = old, let new = new else {
        return old != new // If one is nil and the other isn't, we need to update
    }

    // Helper closure to check if a URL should be updated (if file changed or expired)
    func urlNeedsUpdate(_ oldUrl: String?, _ newUrl: String?) -> Bool {
        guard let oldUrl, let newUrl else { return oldUrl != newUrl } // One nil, one not? Update needed

        let oldBase = oldUrl.components(separatedBy: "?").first
        let newBase = newUrl.components(separatedBy: "?").first

        if oldBase != newBase {
            return true
        }

        // If base URLs are same, check if old URL has expired
        guard let oldDate = extractTimestamp(from: oldUrl) else {
            return true // If can't get timestamp, assume update needed
        }

        let expirationDate = oldDate.addingTimeInterval(threshold)
        let now = Date()

        if now > expirationDate {
            // expired
            return true
        }

        // Same file, not expired
        return false
    }

    // Check for update across all quality levels
    return urlNeedsUpdate(old.highQualityUrl, new.highQualityUrl) ||
    urlNeedsUpdate(old.medQualityUrl, new.medQualityUrl) ||
    urlNeedsUpdate(old.lowQualityUrl, new.lowQualityUrl)
}

/// Checks if video URLs need updating based on file changes or S3 URL expiration.
///
/// This function follows the same pattern as `shouldUpdatePhotoUrls` but for video URLs.
/// It checks if the base file path has changed or if the S3 presigned URL has expired.
/// Video URLs use the same `MediaUrls` structure as photo URLs.
///
/// - Parameters:
///   - old: The existing video URLs (optional)
///   - new: The new video URLs from API (optional)
///   - threshold: Expiration threshold in seconds (default: 3600 = 1 hour)
/// - Returns: `true` if URLs should be updated, `false` otherwise
func shouldUpdateVideoUrls(_ old: MediaUrls?, _ new: MediaUrls?, threshold: TimeInterval = 3600) -> Bool {
    guard let old = old, let new = new else {
        return old != new // If one is nil and the other isn't, we need to update
    }

    // Helper closure to check if a URL should be updated (if file changed or expired)
    func urlNeedsUpdate(_ oldUrl: String?, _ newUrl: String?) -> Bool {
        guard let oldUrl, let newUrl else { return oldUrl != newUrl } // One nil, one not? Update needed

        let oldBase = oldUrl.components(separatedBy: "?").first
        let newBase = newUrl.components(separatedBy: "?").first

        if oldBase != newBase {
            return true
        }

        // If base URLs are same, check if old URL has expired
        guard let oldDate = extractTimestamp(from: oldUrl) else {
            return true // If can't get timestamp, assume update needed
        }

        let expirationDate = oldDate.addingTimeInterval(threshold)
        let now = Date()

        if now > expirationDate {
            // expired
            return true
        }

        // Same file, not expired
        return false
    }

    // For Live Photos, we only have one video quality level (full resolution)
    return urlNeedsUpdate(old.url, new.url)
}
