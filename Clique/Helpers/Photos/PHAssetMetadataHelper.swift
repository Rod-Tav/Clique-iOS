//
//  PHAssetMetadataHelper.swift
//  Clique
//
//  Created by Assistant on PHAsset metadata extraction for timezone.
//

import Photos
import UIKit
import ImageIO

/// Helper for extracting metadata from PHAsset, particularly timezone information and creation dates.
///
/// Reads EXIF data from photo library assets to get the original timezone and creation date
/// in the timezone where the photo was taken.
struct PHAssetMetadataHelper {

    /// Extracts both timezone offset AND creation date from a PHAsset.
    ///
    /// CRITICAL: Uses EXIF DateTimeOriginal (local time) instead of PHAsset.creationDate (UTC).
    /// Apple Photos displays the local time from EXIF, not UTC time.
    ///
    /// Tries in order:
    /// 1. PHAsset.location with GPS reverse geocoding (most reliable, persists through iCloud sync)
    /// 2. EXIF OffsetTimeOriginal/OffsetTime/OffsetTimeDigitized fields
    /// 3. GPS data from image EXIF metadata
    /// 4. Returns DateTimeOriginal with nil timezone if all methods fail
    ///
    /// - Parameter asset: The PHAsset to extract metadata from
    /// - Returns: Tuple of (creationDate in local time, timezone offset or nil)
    static func extractCreationDateAndTimezone(from asset: PHAsset) async -> (date: Date, timezoneOffset: String?)? {
        // Request image data to access EXIF metadata
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                guard let data = data,
                      let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                      let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
                    print("❌ [METADATA] Failed to extract image metadata")
                    // Fallback to PHAsset.creationDate if EXIF not available
                    continuation.resume(returning: (asset.creationDate ?? Date(), nil))
                    return
                }

                // Extract EXIF data
                guard let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
                    print("⚠️ [METADATA] No EXIF data found, using PHAsset.creationDate")
                    continuation.resume(returning: (asset.creationDate ?? Date(), nil))
                    return
                }

                // Extract DateTimeOriginal (local time when photo was taken)
                guard let dateTimeOriginal = exif["DateTimeOriginal"] as? String else {
                    print("⚠️ [METADATA] No DateTimeOriginal in EXIF, using PHAsset.creationDate")
                    continuation.resume(returning: (asset.creationDate ?? Date(), nil))
                    return
                }

                print("📸 [METADATA] Found DateTimeOriginal: \(dateTimeOriginal)")
                print("📸 [METADATA] All EXIF keys: \(exif.keys.joined(separator: ", "))")

                // Try to extract timezone offset
                // PRIORITY 1: Try EXIF OffsetTimeOriginal (most reliable, directly from camera)
                var timezoneOffset: String? = nil
                let timezoneKeys = ["OffsetTimeOriginal", "OffsetTime", "OffsetTimeDigitized"]
                for key in timezoneKeys {
                    if let offset = exif[key] as? String {
                        let cleanOffset = offset.replacingOccurrences(of: ":", with: "")
                        print("✅ [TIMEZONE] Extracted from EXIF[\(key)]: \(cleanOffset)")
                        timezoneOffset = cleanOffset
                        break
                    }
                }

                // PRIORITY 2: Try GPS from EXIF metadata
                if timezoneOffset == nil,
                   let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                   let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                   let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
                   let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
                   let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {

                    let lat = (latRef == "N") ? latitude : -latitude
                    let lon = (lonRef == "E") ? longitude : -longitude
                    let location = CLLocation(latitude: lat, longitude: lon)

                    print("🌍 [TIMEZONE] Trying GPS-based timezone inference...")
                    CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                        if let timeZone = placemarks?.first?.timeZone,
                           let date = asset.creationDate {
                            let offsetSeconds = timeZone.secondsFromGMT(for: date)
                            let offsetString = formatTimezoneOffset(offsetSeconds)
                            print("✅ [TIMEZONE] Extracted from GPS: \(offsetString)")

                            // Parse DateTimeOriginal with timezone
                            let localDate = Self.parseDateTimeOriginal(dateTimeOriginal, withTimezoneOffset: offsetString)
                            continuation.resume(returning: (localDate ?? asset.creationDate ?? Date(), offsetString))
                        } else {
                            print("❌ [TIMEZONE] GPS geocoding failed")
                            // Parse without timezone
                            let localDate = Self.parseDateTimeOriginal(dateTimeOriginal, withTimezoneOffset: nil)
                            continuation.resume(returning: (localDate ?? asset.creationDate ?? Date(), nil))
                        }
                    }
                    return
                }

                // Parse DateTimeOriginal with timezone (if found)
                let localDate = Self.parseDateTimeOriginal(dateTimeOriginal, withTimezoneOffset: timezoneOffset)
                print("📅 [METADATA] Parsed date: \(localDate?.description ?? "nil"), timezone: \(timezoneOffset ?? "nil")")
                continuation.resume(returning: (localDate ?? asset.creationDate ?? Date(), timezoneOffset))
            }
        }
    }

    /// Parses EXIF DateTimeOriginal string to Date
    /// Format: "2025:10:21 20:05:49"
    ///
    /// CRITICAL: Parses time in the original timezone to get correct absolute time.
    /// EXIF DateTimeOriginal is local time, so we parse it in the original timezone
    /// to get a Date object representing the correct UTC instant.
    /// Example: "20:05:49" with "-0400" → Date representing "00:05:49 UTC" (8:05 PM EDT)
    private static func parseDateTimeOriginal(_ dateTimeOriginal: String, withTimezoneOffset offset: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Parse in the original timezone to get correct absolute time
        if let offset = offset, let timezone = TimeZone(offsetString: offset) {
            formatter.timeZone = timezone
            print("📅 [PARSE] Parsing DateTimeOriginal in original timezone \(offset)")
        } else {
            // Fallback to UTC if timezone unknown
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            print("📅 [PARSE] Parsing DateTimeOriginal as UTC (no timezone info)")
        }

        return formatter.date(from: dateTimeOriginal)
    }

    /// Formats seconds offset to ISO 8601 timezone string
    /// Example: -14400 → "-0400", +19800 → "+0530"
    private static func formatTimezoneOffset(_ seconds: Int) -> String {
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        return String(format: "%@%02d%02d", sign, hours, minutes)
    }
}
