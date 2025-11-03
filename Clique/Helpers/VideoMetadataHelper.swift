//
//  VideoMetadataHelper.swift
//  Clique
//
//  Created by Assistant on Video metadata extraction for timezone preservation.
//

import Foundation
import AVFoundation

/// Helper for extracting metadata from video files, particularly timezone information.
///
/// ## Purpose
/// Extracts timezone offset from video files to display dates in the original timezone
/// where the video/Live Photo was captured. This enables timezone preservation without
/// backend changes by reading metadata directly from video files.
///
/// ## Usage
/// ```swift
/// if let offset = await VideoMetadataHelper.extractTimezoneOffset(from: videoURL) {
///     // Use offset to display date in original timezone
///     let tz = TimeZone(offsetString: offset) // e.g., "-0400"
/// }
/// ```
struct VideoMetadataHelper {

    /// Extracts timezone offset from video metadata.
    ///
    /// Reads the QuickTime creation date metadata which includes timezone information
    /// in ISO 8601 format (e.g., "2025-10-21T20:05:51-0400").
    ///
    /// - Parameter url: URL to the video file (local or remote)
    /// - Returns: Timezone offset string (e.g., "-0400", "+0530") or nil if not found
    static func extractTimezoneOffset(from url: URL) async -> String? {
        print("🎬 [VIDEO-META] Starting extraction from: \(url.absoluteString)")
        let asset = AVAsset(url: url)

        do {
            // Load metadata from the video asset
            print("🎬 [VIDEO-META] Loading metadata...")
            let metadata = try await asset.load(.metadata)
            print("🎬 [VIDEO-META] Found \(metadata.count) metadata items")

            // Look for QuickTime creation date (includes timezone)
            for (index, item) in metadata.enumerated() {
                print("🎬 [VIDEO-META] Item \(index): identifier=\(item.identifier?.rawValue ?? "nil"), commonKey=\(item.commonKey?.rawValue ?? "nil")")

                // QuickTime creation date identifier
                if item.identifier == .quickTimeMetadataCreationDate {
                    print("🎬 [VIDEO-META] Found QuickTime creation date!")
                    if let dateString = try await item.load(.stringValue) {
                        print("🎬 [VIDEO-META] Date string: \(dateString)")
                        // Parse timezone offset from ISO 8601 date string
                        // Format: "2025-10-21T20:05:51-0400"
                        if let offset = extractOffsetFromISO8601(dateString) {
                            print("✅ [VIDEO-META] Extracted timezone: \(offset)")
                            return offset
                        } else {
                            print("⚠️ [VIDEO-META] Date string has no timezone offset")
                        }
                    } else {
                        print("⚠️ [VIDEO-META] Could not load string value")
                    }
                }

                // Also check common metadata creation date
                if item.commonKey == .commonKeyCreationDate {
                    print("🎬 [VIDEO-META] Found common creation date!")
                    if let dateString = try await item.load(.stringValue) {
                        print("🎬 [VIDEO-META] Date string: \(dateString)")
                        if let offset = extractOffsetFromISO8601(dateString) {
                            print("✅ [VIDEO-META] Extracted timezone: \(offset)")
                            return offset
                        } else {
                            print("⚠️ [VIDEO-META] Date string has no timezone offset")
                        }
                    } else {
                        print("⚠️ [VIDEO-META] Could not load string value")
                    }
                }
            }

            print("❌ [VIDEO-META] No creation date metadata found")
            return nil

        } catch {
            print("❌ [VIDEO-META] Exception: \(error.localizedDescription)")
            print("   Error: \(error)")
            return nil
        }
    }

    /// Extracts timezone offset from ISO 8601 date string.
    ///
    /// Parses strings like:
    /// - "2025-10-21T20:05:51-0400" → "-0400"
    /// - "2025-10-21T20:05:51+05:30" → "+0530"
    ///
    /// - Parameter dateString: ISO 8601 formatted date string with timezone
    /// - Returns: Timezone offset string or nil
    private static func extractOffsetFromISO8601(_ dateString: String) -> String? {
        // Match timezone offset at end: +HH:MM or -HH:MM
        let pattern = #"([+-]\d{2}):?(\d{2})$"#

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)) {

            if let signRange = Range(match.range(at: 1), in: dateString),
               let hoursRange = Range(match.range(at: 1), in: dateString),
               let minutesRange = Range(match.range(at: 2), in: dateString) {

                let sign = String(dateString[signRange]).prefix(1)
                let hours = String(dateString[hoursRange]).suffix(2)
                let minutes = String(dateString[minutesRange])

                // Format as ±HHMM (e.g., "-0400", "+0530")
                return "\(sign)\(hours)\(minutes)"
            }
        }

        return nil
    }

    /// Extracts full creation date with timezone from video metadata.
    ///
    /// - Parameter url: URL to the video file
    /// - Returns: Tuple of (Date, timezone offset string) or nil
    static func extractCreationDateWithTimezone(from url: URL) async -> (date: Date, offset: String)? {
        let asset = AVAsset(url: url)

        do {
            let metadata = try await asset.load(.metadata)

            for item in metadata {
                if item.identifier == .quickTimeMetadataCreationDate ||
                   item.commonKey == .commonKeyCreationDate {

                    if let dateString = try await item.load(.stringValue) {
                        // Parse full ISO 8601 date with timezone
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]

                        if let date = formatter.date(from: dateString),
                           let offset = extractOffsetFromISO8601(dateString) {
                            return (date, offset)
                        }
                    }
                }
            }

            return nil

        } catch {
            print("❌ Failed to extract creation date from video: \(error.localizedDescription)")
            return nil
        }
    }
}
