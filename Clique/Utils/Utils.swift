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

    func formatter(for format: String, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!, locale: Locale = Locale(identifier: "en_US_POSIX")) -> DateFormatter {
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


func convertToDate(_ dateCreated: String?) -> Date {
    guard let dateCreated else {
        print("Returning because null")
        return Date()
    }

    let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm'Z'",
        "yyyy-MM-dd'T'HH:mm"
    ]

    for format in formats {
        let formatter = DateFormatterCache.shared.formatter(for: format)
        if let date = formatter.date(from: dateCreated) {
            return date
        }
    }

    print("❌ Failed to parse: \(dateCreated)")
    return Date()
}

func convertFromDate(_ date: Date) -> String {
    let formatter = DateFormatterCache.shared.formatter(for: "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'")
    return formatter.string(from: date)
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
