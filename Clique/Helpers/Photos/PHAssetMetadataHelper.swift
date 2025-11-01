//
//  PHAssetMetadataHelper.swift
//  Clique
//
//  Created by Assistant on PHAsset metadata extraction for timezone.
//

import Photos
import UIKit
import ImageIO

/// Helper for extracting metadata from PHAsset, particularly timezone information.
///
/// Reads EXIF data from photo library assets to get the original timezone
/// where the photo was taken.
struct PHAssetMetadataHelper {

    /// Extracts timezone offset from a PHAsset's EXIF metadata.
    ///
    /// - Parameter asset: The PHAsset to extract timezone from
    /// - Returns: Timezone offset string (e.g., "-0400", "+0530") or nil if not available
    static func extractTimezoneOffset(from asset: PHAsset) async -> String? {
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
                    continuation.resume(returning: nil)
                    return
                }

                // Extract timezone from EXIF data
                if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    print("📸 [TIMEZONE] Found EXIF data, checking for OffsetTimeOriginal...")
                    // Try OffsetTimeOriginal first (most accurate)
                    if let offset = exif["OffsetTimeOriginal"] as? String {
                        // Clean format: "-04:00" → "-0400"
                        let cleanOffset = offset.replacingOccurrences(of: ":", with: "")
                        print("✅ [TIMEZONE] Extracted from EXIF: \(cleanOffset) (original: \(offset))")
                        continuation.resume(returning: cleanOffset)
                        return
                    } else {
                        print("⚠️ [TIMEZONE] OffsetTimeOriginal not found in EXIF")
                    }
                } else {
                    print("⚠️ [TIMEZONE] No EXIF data found in image metadata")
                }

                // If no offset in EXIF, try to infer from GPS
                if let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                   let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                   let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
                   let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
                   let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {

                    let lat = (latRef == "N") ? latitude : -latitude
                    let lon = (lonRef == "E") ? longitude : -longitude
                    let location = CLLocation(latitude: lat, longitude: lon)

                    // Use geocoding to get timezone
                    print("🌍 [TIMEZONE] Trying GPS-based timezone inference...")
                    CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                        if let timeZone = placemarks?.first?.timeZone,
                           let date = asset.creationDate {
                            let offsetSeconds = timeZone.secondsFromGMT(for: date)
                            let offsetString = formatTimezoneOffset(offsetSeconds)
                            print("✅ [TIMEZONE] Extracted from GPS: \(offsetString)")
                            continuation.resume(returning: offsetString)
                        } else {
                            print("❌ [TIMEZONE] GPS geocoding failed: \(error?.localizedDescription ?? "unknown")")
                            continuation.resume(returning: nil)
                        }
                    }
                    return
                }

                // No timezone information found
                print("❌ [TIMEZONE] No timezone information found (no EXIF offset, no GPS)")
                continuation.resume(returning: nil)
            }
        }
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
