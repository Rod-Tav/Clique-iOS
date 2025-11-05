//
//  VideoDurationHelper.swift
//  Clique
//
//  Created by Assistant on Video duration fetching implementation.
//

import Foundation
import AVFoundation

/// Helper for fetching video duration from URLs.
///
/// ## Usage
/// ```swift
/// if let duration = await VideoDurationHelper.getDuration(from: videoURL) {
///     print("Duration: \(duration) seconds")
/// }
/// ```
struct VideoDurationHelper {
    /// Asynchronously fetches the duration of a video from a URL.
    ///
    /// - Parameter url: The URL of the video (local or remote)
    /// - Returns: The duration in seconds, or nil if fetching fails
    static func getDuration(from url: URL) async -> TimeInterval? {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            print("❌ Failed to load video duration: \(error.localizedDescription)")
            return nil
        }
    }

    /// Formats a duration in seconds to a human-readable string (e.g., "1:23" or "0:45")
    ///
    /// - Parameter duration: Duration in seconds
    /// - Returns: Formatted string like "M:SS"
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
