//
//  KingfisherConfig.swift
//  Clique
//
//  Created by Rod Tavangar on 3/14/25.
//

import Foundation
import Kingfisher
import UIKit

struct KingfisherConfig {
    static func configure() {
        let cache = ImageCache.default

        // Detect device capabilities for optimal configuration
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let isProDevice = UIDevice.current.userInterfaceIdiom == .phone && totalMemory > 6_000_000_000 // 6GB+ RAM
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        #if DEBUG
        // ⚠️ DEBUG MODE: Simplified configuration for Xcode performance
        // When running from Xcode, debug overhead (Metal validation, logging, etc.)
        // makes production-level config unresponsive. Use minimal settings.

        // Reduced memory cache for debug builds (50% of production)
        let optimalMemoryCache = Int(Double(totalMemory) * 0.075) // 7.5% vs 15% production
        cache.memoryStorage.config.totalCostLimit = min(optimalMemoryCache, isIPad ? 300 * 1024 * 1024 : (isProDevice ? 200 * 1024 * 1024 : 100 * 1024 * 1024))
        cache.memoryStorage.config.expiration = .seconds(1800) // 30 minutes vs 1 hour
        cache.memoryStorage.config.countLimit = isIPad ? 600 : (isProDevice ? 400 : 250)
        cache.memoryStorage.config.cleanInterval = 60 // Clean every 1 minute vs 2 minutes

        // Reduced disk cache for debug
        cache.diskStorage.config.sizeLimit = isIPad ? 1 * 1024 * 1024 * 1024 : 512 * 1024 * 1024 // 1GB/512MB vs 2GB/1GB
        cache.diskStorage.config.expiration = .days(3) // 3 days vs 7 days

        // Enable iCloud backup exclusion
        var mutableURL = cache.diskStorage.directoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(resourceValues)

        let screenScale = UIScreen.main.scale

        // DEBUG: Minimal default options - no heavy processing
        KingfisherManager.shared.defaultOptions = [
            .scaleFactor(screenScale),
            .cacheOriginalImage,
            // NO .processor - skip expensive downsampling
            // NO .backgroundDecode - too heavy in debug
            // NO .cacheSerializer - skip compression overhead
            .callbackQueue(.dispatch(.global(qos: .userInitiated))),
            .transition(.none)
        ]

        // Debug downloader config - sequential loading only
        let downloader = KingfisherManager.shared.downloader
        downloader.downloadTimeout = 15 // Shorter timeout in debug

        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1 // Sequential loading in debug (vs 3 in production)
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        downloader.sessionConfiguration = config

        // NO progressive JPEG in debug - skip overhead
        // NO retry strategy in debug - fail fast

        print("⚠️ Kingfisher configured for DEBUG mode (Xcode performance):")
        print("   - Memory cache: \(cache.memoryStorage.config.totalCostLimit / 1024 / 1024)MB")
        print("   - Disk cache: \(cache.diskStorage.config.sizeLimit / 1024 / 1024)MB")
        print("   - Concurrent downloads: 1 (sequential)")
        print("   - Processing: Minimal (no downsampling/decode)")
        print("   - Device type: \(isIPad ? "iPad" : (isProDevice ? "iPhone Pro" : "iPhone Standard"))")

        #else
        // 🚀 PRODUCTION MODE: Full Instagram-level performance

        // Memory cache configuration - optimized for Instagram-level performance
        // Instagram uses ~15-20% of device RAM for image caching
        let optimalMemoryCache = Int(Double(totalMemory) * 0.15)
        cache.memoryStorage.config.totalCostLimit = min(optimalMemoryCache, isIPad ? 600 * 1024 * 1024 : (isProDevice ? 400 * 1024 * 1024 : 200 * 1024 * 1024))
        cache.memoryStorage.config.expiration = .seconds(3600) // 1 hour
        cache.memoryStorage.config.countLimit = isIPad ? 1200 : (isProDevice ? 800 : 500)

        // Auto-clean memory cache when receiving memory warnings
        cache.memoryStorage.config.cleanInterval = 120 // Clean expired items every 2 minutes

        // Disk cache configuration - increase for better persistence
        cache.diskStorage.config.sizeLimit = isIPad ? 2 * 1024 * 1024 * 1024 : 1024 * 1024 * 1024 // 2GB for iPad, 1GB for iPhone
        cache.diskStorage.config.expiration = .days(7) // Cache expires after 7 days

        // Enable iCloud backup exclusion for cache directory
        var mutableURL = cache.diskStorage.directoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(resourceValues)

        // Configure image processor for optimal quality and performance
        let screenSize = UIScreen.main.bounds.size
        let screenScale = UIScreen.main.scale

        // Different processors for different use cases (will be overridden per image as needed)
        let maxDimension = max(screenSize.width, screenSize.height) * screenScale

        // Use 1.5x screen size for standard quality, allows zooming without pixelation
        let standardProcessor = DownsamplingImageProcessor(size: CGSize(width: maxDimension * 1.5, height: maxDimension * 1.5))

        // Configure default options for Instagram-level performance
        KingfisherManager.shared.defaultOptions = [
            .processor(standardProcessor),
            .scaleFactor(screenScale),
            .cacheOriginalImage,
            .backgroundDecode, // Critical for smooth scrolling
            .preloadAllAnimationData, // For GIFs if any
            .cacheSerializer(FormatIndicatedCacheSerializer.jpeg(compressionQuality: 0.9)), // JPEG for smaller file size with good quality
            .callbackQueue(.dispatch(.global(qos: .userInitiated))), // Process callbacks on background queue
            .transition(.none) // Transitions handled at view level for better control
        ]

        // Configure downloader for better network performance
        let downloader = KingfisherManager.shared.downloader
        downloader.downloadTimeout = 30 // 30 seconds timeout for user-initiated loads

        // Configure URLSession for optimal performance
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 3 // Parallel downloads for smooth experience
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .returnCacheDataElseLoad
        downloader.sessionConfiguration = config

        // Enable progressive JPEG loading for better perceived performance
        KingfisherManager.shared.defaultOptions.append(.progressiveJPEG(.init()))

        // Add retry strategy for failed downloads with progressive delays
        // This helps with poor network conditions (airplane WiFi, etc.)
        let retryStrategy = DelayRetryStrategy(
            maxRetryCount: 2,  // Try up to 3 times total (original + 2 retries)
            retryInterval: .accumulated(2)  // 2s, 4s, 6s progressive delays
        )
        KingfisherManager.shared.defaultOptions.append(.retryStrategy(retryStrategy))

        print("✅ Kingfisher configured for PRODUCTION mode (Instagram-level performance):")
        print("   - Memory cache: \(cache.memoryStorage.config.totalCostLimit / 1024 / 1024)MB")
        print("   - Disk cache: \(cache.diskStorage.config.sizeLimit / 1024 / 1024 / 1024)GB")
        print("   - Concurrent downloads: 3 (parallel)")
        print("   - Processing: Full (downsampling + decode + compression)")
        print("   - Device type: \(isIPad ? "iPad" : (isProDevice ? "iPhone Pro" : "iPhone Standard"))")
        #endif
    }
}
