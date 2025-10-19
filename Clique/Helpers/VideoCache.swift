//
//  VideoCache.swift
//  Clique
//
//  Created by Assistant on Video caching implementation.
//

import Foundation

/// Lightweight video cache manager for caching videos from network URLs.
///
/// ## Overview
/// Downloads videos from S3 URLs and caches them locally with `.mp4` extension,
/// allowing AVPlayer to properly detect video format without backend changes.
///
/// ## Features
/// - **Automatic Caching**: Downloads and caches videos on first access
/// - **LRU Eviction**: Removes least recently used videos when cache is full
/// - **Thread-Safe**: All operations are synchronized
/// - **Memory Efficient**: Only stores file URLs, not video data in memory
///
/// ## Usage
/// ```swift
/// let cache = VideoCache.shared
/// let localURL = try await cache.getVideo(from: s3URL)
/// let player = AVPlayer(url: localURL)
/// ```
actor VideoCache {
    static let shared = VideoCache()

    // Cache configuration
    private let maxCacheSize: Int64 = 500 * 1024 * 1024  // 500MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    // Cache directory
    private let cacheDirectory: URL

    // Track access times for LRU eviction
    private var accessTimes: [String: Date] = [:]

    private init() {
        // Create cache directory in Caches folder
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDirectory.appendingPathComponent("VideoCache", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        print("📂 VideoCache initialized at: \(cacheDirectory.path)")
    }

    /// Get video from cache or download if not cached
    func getVideo(from url: URL) async throws -> URL {
        let cacheKey = cacheKeyFor(url)
        let cachedURL = cacheDirectory.appendingPathComponent(cacheKey).appendingPathExtension("mp4")

        // Check if already cached
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            print("✅ Video cache hit: \(cacheKey)")
            updateAccessTime(for: cacheKey)
            return cachedURL
        }

        print("⬇️ Downloading video: \(url.lastPathComponent)")

        // Download video
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VideoCacheError.downloadFailed
        }

        // Write to cache
        try data.write(to: cachedURL)
        updateAccessTime(for: cacheKey)

        print("💾 Cached video: \(cacheKey) (\(data.count / 1024)KB)")

        // Verify file was written successfully
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: cachedURL.path),
               let fileSize = attrs[.size] as? Int64 {
                print("✅ File verification: exists, size=\(fileSize) bytes")
            }
        } else {
            print("⚠️ File verification failed: file does not exist at path")
        }

        // Check HTTP response headers
        if let httpResponse = response as? HTTPURLResponse {
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                print("📄 Content-Type: \(contentType)")
            }
        }

        // Cleanup old videos if needed
        await cleanupIfNeeded()

        return cachedURL
    }

    /// Check if video is cached
    func isCached(_ url: URL) -> Bool {
        let cacheKey = cacheKeyFor(url)
        let cachedURL = cacheDirectory.appendingPathComponent(cacheKey).appendingPathExtension("mp4")
        return FileManager.default.fileExists(atPath: cachedURL.path)
    }

    /// Clear all cached videos
    func clearCache() async {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
            accessTimes.removeAll()
            print("🗑️ Cleared video cache")
        } catch {
            print("❌ Failed to clear cache: \(error)")
        }
    }

    /// Get current cache size in bytes
    func getCacheSize() -> Int64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            return contents.reduce(0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Int64(size)
            }
        } catch {
            return 0
        }
    }

    // MARK: - Private Helpers

    private func cacheKeyFor(_ url: URL) -> String {
        // Use the UUID from the S3 path as cache key
        // Example: .../49838036-bcb3-4978-8455-5a9eb5ebadd9?... -> 49838036-bcb3-4978-8455-5a9eb5ebadd9
        let pathComponents = url.path.components(separatedBy: "/")
        if let lastComponent = pathComponents.last, !lastComponent.isEmpty {
            return lastComponent
        }

        // Fallback: hash the full URL
        return url.absoluteString.sha256()
    }

    private func updateAccessTime(for key: String) {
        accessTimes[key] = Date()
    }

    private func cleanupIfNeeded() async {
        let currentSize = getCacheSize()

        // Check if over size limit
        if currentSize > maxCacheSize {
            await evictLRU(targetSize: maxCacheSize * 80 / 100)  // Reduce to 80% of max
        }

        // Remove old videos
        await removeExpiredVideos()
    }

    private func evictLRU(targetSize: Int64) async {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            )

            // Sort by access time (least recent first)
            let sortedFiles = contents.sorted { url1, url2 in
                let key1 = url1.deletingPathExtension().lastPathComponent
                let key2 = url2.deletingPathExtension().lastPathComponent
                let time1 = accessTimes[key1] ?? Date.distantPast
                let time2 = accessTimes[key2] ?? Date.distantPast
                return time1 < time2
            }

            var currentSize = getCacheSize()
            var evictedCount = 0

            for url in sortedFiles {
                guard currentSize > targetSize else { break }

                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                try? FileManager.default.removeItem(at: url)

                let key = url.deletingPathExtension().lastPathComponent
                accessTimes.removeValue(forKey: key)

                currentSize -= Int64(size)
                evictedCount += 1
            }

            if evictedCount > 0 {
                print("🗑️ Evicted \(evictedCount) videos (LRU)")
            }
        } catch {
            print("❌ Failed to evict LRU: \(error)")
        }
    }

    private func removeExpiredVideos() async {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
            var removedCount = 0

            for url in contents {
                let modificationDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

                if let date = modificationDate, date < cutoffDate {
                    try? FileManager.default.removeItem(at: url)
                    let key = url.deletingPathExtension().lastPathComponent
                    accessTimes.removeValue(forKey: key)
                    removedCount += 1
                }
            }

            if removedCount > 0 {
                print("🗑️ Removed \(removedCount) expired videos")
            }
        } catch {
            print("❌ Failed to remove expired videos: \(error)")
        }
    }
}

// MARK: - Error Types

enum VideoCacheError: Error {
    case downloadFailed
    case writeFailed
    case invalidURL
}

// MARK: - String Extensions

private extension String {
    func sha256() -> String {
        // Simple hash function for cache keys
        return String(self.hashValue)
    }
}
