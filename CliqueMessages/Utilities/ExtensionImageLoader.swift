//
//  ExtensionImageLoader.swift
//  CliqueMessages
//
//  Lightweight image loader for iMessage extension with strict memory constraints.
//  Uses URLSession for networking, App Group container for disk caching,
//  and NSCache for memory caching with size limits.
//

import UIKit


// MARK: - Image Phase

/// Represents the loading phase of an image
public enum ImagePhase: Sendable {
    case loading
    case loaded(UIImage)
    case failed(Error?)
}

// MARK: - Extension Image Loader

/// Lightweight image loader designed for iMessage extension's ~30MB memory limit.
/// Provides disk caching in App Group container and small in-memory cache.
/// Thread-safe and handles S3 signed URL expiration gracefully.
public final class ExtensionImageLoader: @unchecked Sendable {
    public static let shared = ExtensionImageLoader()

    // MARK: - Configuration

    private let memoryLimit = 10 * 1024 * 1024 // 10MB memory cache limit
    private let memoryCacheCountLimit = 50 // Max number of images in memory
    private let diskCacheMaxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    // MARK: - Properties

    private let memoryCache: NSCache<NSString, UIImage>
    private let urlSession: URLSession
    private let fileManager = FileManager.default
    private var activeTasks: [String: Task<UIImage, Error>] = [:]
    private let taskQueue = DispatchQueue(label: "com.clique.extension.imageloader", attributes: .concurrent)

    // MARK: - Initialization

    private init() {
        // Configure memory cache with size limits
        self.memoryCache = NSCache<NSString, UIImage>()
        self.memoryCache.totalCostLimit = memoryLimit
        self.memoryCache.countLimit = memoryCacheCountLimit

        // Configure URLSession for efficient image loading
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = nil // We handle our own caching
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: config)

        // Ensure cache directory exists
        AppGroupManager.shared.ensureThumbnailsDirectoryExists()

        // Clean old cache on init
        cleanExpiredCache()
    }

    // MARK: - Public API

    /// Load an image from URL with caching
    /// - Parameter url: The image URL to load
    /// - Returns: The loaded UIImage
    /// - Throws: Loading errors including network, decode, or cancellation errors
    public func loadImage(from url: URL) async throws -> UIImage {
        let cacheKey = cacheKey(for: url)

        // Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        // Check if there's already an in-flight request for this URL
        let existingTask = taskQueue.sync { activeTasks[cacheKey] }
        if let task = existingTask {
            return try await task.value
        }

        // Create new task for loading
        let task = Task<UIImage, Error> {
            defer {
                taskQueue.async(flags: .barrier) { [weak self] in
                    self?.activeTasks.removeValue(forKey: cacheKey)
                }
            }

            // Check disk cache
            if let diskImage = try? await loadFromDisk(cacheKey: cacheKey) {
                // Cache in memory for future access
                self.memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
                return diskImage
            }

            // Download from network
            let downloadedImage = try await downloadImage(from: url)

            // Save to disk cache
            Task.detached { [weak self] in
                await self?.saveToDisk(image: downloadedImage, cacheKey: cacheKey)
            }

            // Cache in memory
            self.memoryCache.setObject(downloadedImage, forKey: cacheKey as NSString)

            return downloadedImage
        }

        // Store task for deduplication
        taskQueue.async(flags: .barrier) { [weak self] in
            self?.activeTasks[cacheKey] = task
        }

        return try await task.value
    }

    /// Cancel loading for a specific URL
    /// - Parameter url: The URL to cancel loading for
    public func cancelLoad(for url: URL) {
        let cacheKey = cacheKey(for: url)
        taskQueue.async(flags: .barrier) { [weak self] in
            self?.activeTasks[cacheKey]?.cancel()
            self?.activeTasks.removeValue(forKey: cacheKey)
        }
    }

    /// Clear all cached images from memory and disk
    public func clearCache() {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        guard let cacheDirectory = AppGroupManager.shared.thumbnailsDirectory else { return }
        try? fileManager.removeItem(at: cacheDirectory)
        AppGroupManager.shared.ensureThumbnailsDirectoryExists()
    }

    /// Clear only memory cache (useful for memory pressure)
    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Private Methods

    /// Generate a cache key from URL
    private func cacheKey(for url: URL) -> String {
        // Remove query parameters (like S3 signatures) from cache key
        // This allows cached images to be reused even when signed URLs expire
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        let baseURL = components?.url?.absoluteString ?? url.absoluteString

        // Use MD5-like hash for shorter filenames
        return baseURL.hash.description
    }

    /// Download image from network
    private func downloadImage(from url: URL) async throws -> UIImage {
        print("ExtensionImageLoader: Downloading from \(url.absoluteString.prefix(80))...")

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("ExtensionImageLoader: Invalid response (not HTTP)")
            throw ImageLoaderError.invalidResponse
        }

        print("ExtensionImageLoader: HTTP status \(httpResponse.statusCode) for \(url.lastPathComponent)")

        guard httpResponse.statusCode == 200 else {
            print("ExtensionImageLoader: HTTP error \(httpResponse.statusCode) - URL may have expired")
            throw ImageLoaderError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let image = UIImage(data: data) else {
            print("ExtensionImageLoader: Failed to decode image data (\(data.count) bytes)")
            throw ImageLoaderError.invalidImageData
        }

        print("ExtensionImageLoader: Successfully loaded image \(image.size)")
        return image
    }

    /// Load image from disk cache
    private func loadFromDisk(cacheKey: String) async throws -> UIImage {
        guard let cacheDirectory = AppGroupManager.shared.thumbnailsDirectory else {
            print("ExtensionImageLoader: Disk cache directory unavailable")
            throw ImageLoaderError.cacheDirectoryUnavailable
        }

        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)

        // Check if file exists and is not expired
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("ExtensionImageLoader: Not in disk cache: \(cacheKey)")
            throw ImageLoaderError.notInCache
        }

        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        if let modificationDate = attributes[.modificationDate] as? Date {
            let age = Date().timeIntervalSince(modificationDate)
            if age > diskCacheMaxAge {
                print("ExtensionImageLoader: Disk cache expired for \(cacheKey)")
                try? fileManager.removeItem(at: fileURL)
                throw ImageLoaderError.cacheExpired
            }
        }

        // Load image data
        let data = try Data(contentsOf: fileURL)
        guard let image = UIImage(data: data) else {
            print("ExtensionImageLoader: Failed to decode disk cached image")
            throw ImageLoaderError.invalidImageData
        }

        print("ExtensionImageLoader: Loaded from disk cache: \(cacheKey)")
        return image
    }

    /// Save image to disk cache
    private func saveToDisk(image: UIImage, cacheKey: String) async {
        guard let cacheDirectory = AppGroupManager.shared.thumbnailsDirectory else { return }

        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)

        // Convert to JPEG with compression for smaller file size
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        try? data.write(to: fileURL, options: .atomic)
    }

    /// Clean expired cache files
    private func cleanExpiredCache() {
        Task.detached { [weak self] in
            guard let self = self,
                  let cacheDirectory = AppGroupManager.shared.thumbnailsDirectory else { return }

            guard let files = try? self.fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { return }

            let now = Date()

            for file in files {
                if let attributes = try? self.fileManager.attributesOfItem(atPath: file.path),
                   let modificationDate = attributes[.modificationDate] as? Date {
                    let age = now.timeIntervalSince(modificationDate)
                    if age > self.diskCacheMaxAge {
                        try? self.fileManager.removeItem(at: file)
                    }
                }
            }
        }
    }
}

// MARK: - Image Loader Error

public enum ImageLoaderError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidImageData
    case cacheDirectoryUnavailable
    case notInCache
    case cacheExpired

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .invalidImageData:
            return "Could not decode image data"
        case .cacheDirectoryUnavailable:
            return "Cache directory not available"
        case .notInCache:
            return "Image not found in cache"
        case .cacheExpired:
            return "Cached image expired"
        }
    }
}
