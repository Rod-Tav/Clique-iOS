//
//  Utils.swift
//  Clique
//
//  Created by Rod Tavangar on 10/23/24.
//

import SwiftUI
import Foundation
import CoreLocation

// MARK: - DateFormatter Caching

private class DateFormatterCache {
    static let shared = DateFormatterCache()

    private var cache: [String: DateFormatter] = [:]
    private let queue = DispatchQueue(label: "com.clique.dateformatter.cache")

    private init() {}

    func formatter(for format: String, timeZone: TimeZone = .current, locale: Locale = Locale(identifier: "en_US_POSIX")) -> DateFormatter {
        return queue.sync {
            if let cached = cache[format] {
                return cached
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.timeZone = timeZone
                formatter.locale = locale
                cache[format] = formatter
                return formatter
            }
        }
    }
}

private actor GeocodingRateLimiter {
    static let shared = GeocodingRateLimiter()
    private let semaphore = AsyncSemaphore(value: 1)
    
    func waitAndThrottle() async {
        await semaphore.wait()
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds delay
            await semaphore.signal()
        }
    }
}

private var gpsTimezoneCache = [String: TimeZone]() // Cache for location-based timezones

func formattedWhatsNew(releases: [(version: String, changes: [String])]) -> LocalizedStringKey {
    let formattedReleases = releases.map { release in
        let formattedChanges = release.changes.map { "- \($0)" }.joined(separator: "\n")
        return "**\(release.version)**\n\(formattedChanges)"
    }.joined(separator: "\n\n")
    
    return LocalizedStringKey(formattedReleases)
}

// MARK: - Numbers
func formatNumber(_ num: Int) -> String {
    if num >= 100_000_000 {
        return String(format: "%.0fM", floor(Double(num) / 1_000_000))
    } else if num >= 1_000_000 {
        return String(format: "%.1fM", floor(Double(num) / 100_000) / 10.0)
    } else if num >= 100_000 {
        return String(format: "%.0fk", floor(Double(num) / 1_000))
    } else if num >= 1_000 {
        return String(format: "%.1fk", floor(Double(num) / 100) / 10.0)
    } else {
        return "\(num)"
    }
}

// MARK: - Dates
func extractDate(from metadata: NSDictionary) async -> Date? {
//    print("Metadata received:", metadata)
    
    guard let exifData = metadata["{Exif}"] as? NSDictionary else {
        print("EXIF data not found in metadata.")
        return nil
    }
    
    guard let dateTimeOriginal = exifData["DateTimeOriginal"] as? String else {
        print("DateTimeOriginal not found in EXIF data.")
        return nil
    }
    
    let formatter = DateFormatter()
    
    // 1. Try OffsetTimeOriginal if available
    if let offset = exifData["OffsetTimeOriginal"] as? String {
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
        if let date = formatter.date(from: dateTimeOriginal + offset) {
            return date
        } else {
            print("Failed to parse with offset:", dateTimeOriginal + offset)
        }
    }
    
    // 2. Try reverse geocoding with GPS
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    if let gpsData = metadata["{GPS}"] as? NSDictionary,
       let longitudeRef = gpsData["LongitudeRef"] as? String,
       let latitudeRef = gpsData["LatitudeRef"] as? String,
       let longitude = gpsData["Longitude"] as? Double,
       let latitude = gpsData["Latitude"] as? Double {
        
        let location = CLLocation(latitude: latitudeRef == "N" ? latitude : -latitude,
                                  longitude: longitudeRef == "E" ? longitude : -longitude)
        
        let key = "\(round(latitude * 1000) / 1000),\(round(longitude * 1000) / 1000)"
        
        if let cachedTimeZone = gpsTimezoneCache[key] {
            formatter.timeZone = cachedTimeZone
        } else {
            await GeocodingRateLimiter.shared.waitAndThrottle()
            let timeZone: TimeZone? = await withCheckedContinuation { continuation in
                CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                    continuation.resume(returning: placemarks?.first?.timeZone)
                }
            }
            if let timeZone {
                gpsTimezoneCache[key] = timeZone
                formatter.timeZone = timeZone
            } else {
                formatter.timeZone = TimeZone.current
            }
        }
    } else {
        // 3. Fallback to current time zone
        formatter.timeZone = TimeZone.current
    }
    
    if let date = formatter.date(from: dateTimeOriginal) {
        return date
    } else {
        print("Failed to parse date from string:", dateTimeOriginal)
        return nil
    }
}

/// Formats timezone offset from seconds to string format.
///
/// Converts seconds from GMT to timezone offset string format.
///
/// - Parameter offsetSeconds: Seconds from GMT (e.g., -14400 for EDT, 19800 for IST)
/// - Returns: Timezone offset string (e.g., "-0400", "+0530")
func formatTimezoneOffset(_ offsetSeconds: Int) -> String {
    let hours = abs(offsetSeconds) / 3600
    let minutes = (abs(offsetSeconds) % 3600) / 60
    let sign = offsetSeconds >= 0 ? "+" : "-"
    return String(format: "%@%02d%02d", sign, hours, minutes)
}

/// Geocodes a location to get its timezone using reverse geocoding with caching and rate limiting.
///
/// Uses a cached result if available for nearby locations (within ~100 meters).
/// Applies rate limiting (1.2 second delay) to avoid hitting CLGeocoder limits.
///
/// - Parameters:
///   - location: The CLLocation to geocode
///   - date: The date to use for timezone offset calculation (important for DST)
/// - Returns: Timezone offset string (e.g., "-0400", "+0530") or nil if geocoding fails
func geocodeLocationToTimezone(location: CLLocation, for date: Date) async -> String? {
    let latitude = location.coordinate.latitude
    let longitude = location.coordinate.longitude
    let key = "\(round(latitude * 1000) / 1000),\(round(longitude * 1000) / 1000)"

    var timeZone: TimeZone?
    if let cachedTimeZone = gpsTimezoneCache[key] {
        timeZone = cachedTimeZone
        print("🗺️ [GEOCODE] Using cached timezone for \(key)")
    } else {
        await GeocodingRateLimiter.shared.waitAndThrottle()
        print("🌍 [GEOCODE] Reverse geocoding location: \(latitude), \(longitude)")
        timeZone = await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("❌ [GEOCODE] Failed: \(error.localizedDescription)")
                }
                continuation.resume(returning: placemarks?.first?.timeZone)
            }
        }
        if let timeZone {
            gpsTimezoneCache[key] = timeZone
            print("✅ [GEOCODE] Cached timezone: \(timeZone.identifier)")
        }
    }

    if let timeZone {
        let offsetSeconds = timeZone.secondsFromGMT(for: date)
        let offsetString = formatTimezoneOffset(offsetSeconds)
        return offsetString
    }

    return nil
}

/// Extracts date and timezone offset from photo/video metadata.
///
/// Returns both the Date and the timezone offset string (e.g., "-0400", "+0530")
/// so the offset can be sent to backend for timezone preservation.
///
/// - Parameter metadata: NSDictionary containing EXIF and GPS metadata
/// - Returns: Tuple of (Date, timezone offset string) or nil if extraction fails
func extractDateAndTimezoneOffset(from metadata: NSDictionary) async -> (date: Date, offset: String)? {
    guard let exifData = metadata["{Exif}"] as? NSDictionary else {
        print("EXIF data not found in metadata.")
        return nil
    }

    guard let dateTimeOriginal = exifData["DateTimeOriginal"] as? String else {
        print("DateTimeOriginal not found in EXIF data.")
        return nil
    }

    let formatter = DateFormatter()

    // 1. Try OffsetTimeOriginal if available (most accurate)
    if let offset = exifData["OffsetTimeOriginal"] as? String {
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
        if let date = formatter.date(from: dateTimeOriginal + offset) {
            // Clean offset format: "-04:00" → "-0400"
            let cleanOffset = offset.replacingOccurrences(of: ":", with: "")
            print("✅ Extracted date with timezone offset from EXIF: \(dateTimeOriginal)\(offset) → \(cleanOffset)")
            return (date, cleanOffset)
        } else {
            print("Failed to parse with offset:", dateTimeOriginal + offset)
        }
    }

    // 2. Try reverse geocoding with GPS
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    if let gpsData = metadata["{GPS}"] as? NSDictionary,
       let longitudeRef = gpsData["LongitudeRef"] as? String,
       let latitudeRef = gpsData["LatitudeRef"] as? String,
       let longitude = gpsData["Longitude"] as? Double,
       let latitude = gpsData["Latitude"] as? Double {

        let location = CLLocation(
            latitude: latitudeRef == "N" ? latitude : -latitude,
            longitude: longitudeRef == "E" ? longitude : -longitude
        )

        let key = "\(round(latitude * 1000) / 1000),\(round(longitude * 1000) / 1000)"

        var timeZone: TimeZone?
        if let cachedTimeZone = gpsTimezoneCache[key] {
            timeZone = cachedTimeZone
        } else {
            await GeocodingRateLimiter.shared.waitAndThrottle()
            timeZone = await withCheckedContinuation { continuation in
                CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                    continuation.resume(returning: placemarks?.first?.timeZone)
                }
            }
            if let timeZone {
                gpsTimezoneCache[key] = timeZone
            }
        }

        if let timeZone {
            formatter.timeZone = timeZone
            if let date = formatter.date(from: dateTimeOriginal) {
                let offsetSeconds = timeZone.secondsFromGMT(for: date)
                let offsetString = formatTimezoneOffset(offsetSeconds)
                print("✅ Extracted date with timezone from GPS: \(dateTimeOriginal) → \(offsetString)")
                return (date, offsetString)
            }
        }
    }

    // 3. Fallback to current time zone
    formatter.timeZone = TimeZone.current
    if let date = formatter.date(from: dateTimeOriginal) {
        let offsetSeconds = TimeZone.current.secondsFromGMT(for: date)
        let offsetString = formatTimezoneOffset(offsetSeconds)
        print("⚠️ Using current timezone as fallback: \(dateTimeOriginal) → \(offsetString)")
        return (date, offsetString)
    }

    print("Failed to parse date from string:", dateTimeOriginal)
    return nil
}

/// Converts ISO 8601 string to Date, supporting both UTC ('Z') and timezone offsets.
///
/// Supports formats:
/// - With timezone: "2025-10-21T20:05:00.000000-04:00"
/// - UTC with 'Z': "2025-10-22T00:05:00.000000Z"
/// - No timezone: "2025-10-22T00:05:00.000000" (assumes UTC)
///
/// - Parameter dateCreated: ISO 8601 formatted date string
/// - Returns: Tuple of (Date, timezone offset string or nil)
func convertToDateWithTimezone(_ dateCreated: String?) -> (date: Date, offset: String?)? {
    guard let dateCreated else {
        print("Returning because null")
        return nil
    }

    // Formats with timezone offset (XXXXX = ±HH:MM, XXXX = ±HHMM)
    let formatsWithTimezone = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",  // With timezone: -04:00
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mmXXXXX"
    ]

    // Try parsing with timezone first
    for format in formatsWithTimezone {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: dateCreated) {
            // Extract timezone offset from string
            if let offset = extractTimezoneOffsetFromString(dateCreated) {
                return (date, offset)
            }
        }
    }

    // Fallback to formats without timezone (treat as UTC)
    let formatsUTC = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm'Z'",
        "yyyy-MM-dd'T'HH:mm"
    ]

    for format in formatsUTC {
        let formatter = DateFormatterCache.shared.formatter(
            for: format,
            timeZone: TimeZone(secondsFromGMT: 0)!  // Parse as UTC
        )
        if let date = formatter.date(from: dateCreated) {
            return (date, nil)  // No timezone offset preserved
        }
    }
    return nil
}

/// Legacy function - kept for backward compatibility
func convertToDate(_ dateCreated: String?) -> Date {
    return convertToDateWithTimezone(dateCreated)?.date ?? Date()
}

/// Extracts timezone offset from ISO 8601 string
/// Examples: "2025-10-21T20:05:00-04:00" → "-0400"
///           "2025-10-21T20:05:00+05:30" → "+0530"
private func extractTimezoneOffsetFromString(_ dateString: String) -> String? {
    let pattern = #"([+-]\d{2}):(\d{2})$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)) else {
        return nil
    }

    if let hourRange = Range(match.range(at: 1), in: dateString),
       let minuteRange = Range(match.range(at: 2), in: dateString) {
        let hours = String(dateString[hourRange])
        let minutes = String(dateString[minuteRange])
        return "\(hours)\(minutes)"  // "-0400" format
    }

    return nil
}

/// Converts Date to ISO 8601 string, preserving timezone offset when available.
///
/// If timezone offset is provided, formats with offset (e.g., "2025-10-21T20:05:00.000000-04:00")
/// Otherwise formats as UTC with 'Z' (e.g., "2025-10-22T00:05:00.000000Z")
///
/// - Parameters:
///   - date: The date to convert
///   - timezoneOffset: Optional timezone offset string (e.g., "-0400", "+0530")
/// - Returns: ISO 8601 formatted date string
func convertFromDate(_ date: Date, timezoneOffset: String? = nil) -> String {
    if let offset = timezoneOffset, let timezone = TimeZone(offsetString: offset) {
        // Format with original timezone offset
        let formatter = DateFormatterCache.shared.formatter(
            for: "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",  // XXXXX = timezone with colon (-04:00)
            timeZone: timezone
        )
        let result = formatter.string(from: date)
        print("📤 [UPLOAD] convertFromDate with timezone \(offset) → \(result)")
        return result
    } else {
        // Fallback to UTC with 'Z'
        let formatter = DateFormatterCache.shared.formatter(
            for: "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            timeZone: TimeZone(secondsFromGMT: 0)!  // Force UTC
        )
        let result = formatter.string(from: date)
        print("⚠️ [UPLOAD] convertFromDate WITHOUT timezone → \(result) (using UTC)")
        return result
    }
}

private func formatDateHelper(_ date: Date, _ format: String) -> String {
    let formatter = DateFormatterCache.shared.formatter(for: format)
    return formatter.string(from: date)
}

func formatDateMMMMddYYYY(_ date: Date) -> String {
    return formatDateHelper(date, "MMMM dd, yyyy")
}

func formatDateMMMMdYYYY(_ date: Date) -> String {
    return formatDateHelper(date, "MMMM d, yyyy")
}

func formatDateMMMMdd(_ date: Date) -> String {
    return formatDateHelper(date, "MMMM dd")
}

func formatDateMMddyyyy(_ date: Date) -> String {
    return formatDateHelper(date, "MM dd yyyy")
}

func formatDateHHmm(_ date: Date) -> String {
    return formatDateHelper(date, "h:mm a")
}

func formatDateMdyy(_ date: Date) -> String {
    return formatDateHelper(date, "M/d/yy")
}

func formatDateMMMMyyyy(_ date: Date) -> String {
    return formatDateHelper(date, "MMMM yyyy")
}

func formatRelativeDate(_ date: Date) -> String {
    let now = Date()
    let secondsDifference = Int(now.timeIntervalSince(date))

    if secondsDifference < 86400 { // Less than a day
        if secondsDifference < 3600 {
            let minutes = secondsDifference / 60
            return "\(minutes)m ago"
        } else {
            let hours = secondsDifference / 3600
            return "\(hours)h ago"
        }
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Timezone-Aware Date Formatting

/// Formats date using a specific timezone offset (for displaying dates in original timezone)
///
/// This allows displaying dates in the timezone where a photo/video was taken,
/// rather than the viewer's current timezone.
///
/// - Parameters:
///   - date: The date to format
///   - timezoneOffset: Timezone offset string (e.g., "-0400", "+0530"), or nil for current timezone
///   - format: Date format string (default: "MMMM d, yyyy h:mm a")
/// - Returns: Formatted date string in the specified timezone
func formatDateInOriginalTimezone(
    _ date: Date,
    timezoneOffset: String?,
    format: String = "MMMM d, yyyy h:mm a"
) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.locale = Locale(identifier: "en_US_POSIX")

    if let offset = timezoneOffset,
       let timezone = TimeZone(offsetString: offset) {
        formatter.timeZone = timezone
    } else {
        // When no timezone info available, display in user's current timezone
        // This handles backend dates that don't preserve timezone information
        formatter.timeZone = .current
    }

    return formatter.string(from: date)
}

/// Timezone-aware versions of existing format functions

func formatDateMMMMddYYYYWithTimezone(_ date: Date, timezoneOffset: String?) -> String {
    return formatDateInOriginalTimezone(date, timezoneOffset: timezoneOffset, format: "MMMM dd, yyyy")
}

func formatDateMMMMdYYYYWithTimezone(_ date: Date, timezoneOffset: String?) -> String {
    return formatDateInOriginalTimezone(date, timezoneOffset: timezoneOffset, format: "MMMM d, yyyy")
}

func formatDateHHmmWithTimezone(_ date: Date, timezoneOffset: String?) -> String {
    return formatDateInOriginalTimezone(date, timezoneOffset: timezoneOffset, format: "h:mm a")
}

//func formatDateComments(_ date: Date) -> String {
//    let formatter = DateComponentsFormatter()
//    formatter.allowedUnits = [.second, .minute, .hour, .day, .weekOfMonth]
//    formatter.maximumUnitCount = 1
//    formatter.unitsStyle = .abbreviated
//    return formatter.string(from: date, to: Date()) ?? ""
//}

// MARK: - String Utilities

/// Returns the appropriate singular or plural form of a word based on a count.
/// - Parameters:
///   - count: The count to determine singular or plural.
///   - singular: The singular form of the word.
///   - plural: The plural form of the word.
/// - Returns: A string with the count and the appropriate word form.
func pluralizeWithCount(count: Int, singular: String, plural: String? = nil) -> String {
    let pluralForm = plural ?? singular + "s"
    return "\(count) \(count == 1 ? singular : pluralForm)"
}

func pluralize(count: Int, singular: String, plural: String? = nil) -> String {
    let pluralForm = plural ?? singular + "s"
    return "\(count == 1 ? singular : pluralForm)"
}

@MainActor func isInClique(cid: String, _ cliqueStore: CliqueStore) -> Bool {
    return cliqueStore.cliques[cid]?.relationship?.isInClique ?? false
}

@MainActor func isLeader(cid: String, _ cliqueStore: CliqueStore) -> Bool {
    return cliqueStore.cliques[cid]?.relationship == .leader
}

// MARK: - TimeZone Extensions

extension TimeZone {
    /// Creates a TimeZone from a timezone offset string.
    ///
    /// Supports formats like "-0400", "+0530", "-08:00", "+05:30"
    ///
    /// - Parameter offsetString: Timezone offset string (e.g., "-0400", "+0530")
    /// - Returns: TimeZone if valid format, nil otherwise
    init?(offsetString: String) {
        // Handle both "-0400" and "-04:00" formats
        let cleanOffset = offsetString.replacingOccurrences(of: ":", with: "")

        guard cleanOffset.count == 5,
              let sign = cleanOffset.first,
              (sign == "+" || sign == "-"),
              let hours = Int(cleanOffset.dropFirst().prefix(2)),
              let minutes = Int(cleanOffset.suffix(2)) else {
            return nil
        }

        let totalSeconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        self.init(secondsFromGMT: totalSeconds)
    }
}
