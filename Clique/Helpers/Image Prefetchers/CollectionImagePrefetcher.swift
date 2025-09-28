//
//  CollectionImagePrefetcher.swift
//  Clique
//
//  Created by Rod Tavangar on 3/5/25.
//

/// Intelligent image prefetching system with network quality adaptation.
///
/// ## Overview
///
/// This prefetcher implements Instagram-level prefetching strategies that adapt
/// to network conditions and user behavior patterns.
///
/// ## Architecture
///
/// ```
/// CollectionImagePrefetcher
/// ├── Quality-based Prefetchers (Low/Med/High)
/// ├── Network Quality Monitor
/// ├── Context-aware Strategies
/// └── Memory Pressure Handler
/// ```
///
/// ## Prefetching Strategies
///
/// ### Context-Based Loading
/// - **Feed Scrolling**: Low quality, first 2-4 images
/// - **Detail Viewing**: Medium quality, visible + adjacent
/// - **Grid Browsing**: Low quality, visible rows + 1
/// - **Fullscreen**: High quality, current + next/prev
///
/// ### Network Adaptation
/// ```swift
/// Excellent (80-100%): Full prefetch all qualities
/// Good (50-80%): Skip high quality prefetch
/// Poor (20-50%): Only critical images
/// Very Poor (0-20%): Skip all prefetching
/// ```
///
/// ## Performance Optimizations
///
/// ### Debouncing
/// - 300ms delay for prefetch requests
/// - Prevents excessive operations during fast scrolling
/// - Batches multiple requests together
///
/// ### Concurrent Limits
/// - Maximum 2 concurrent prefetch operations
/// - Prevents UI thread blocking
/// - Cancels old operations for new ones
///
/// ### Memory Management
/// - Monitors system memory warnings
/// - Cancels all prefetching under pressure
/// - Clears prefetch history to free memory
///
/// ## Usage Example
///
/// ```swift
/// // In a collection view
/// CollectionImagePrefetcher.instance.prefetchForContext(
///     .feedScroll,
///     collectionId: collection.id,
///     images: collection.images
/// )
///
/// // Stop when view disappears
/// CollectionImagePrefetcher.instance.stopPrefetching(
///     for: collection.id
/// )
/// ```
///
/// ## Network Quality Tracking
///
/// The system tracks the last 50 prefetch results to assess network quality:
/// - Success/failure ratio determines quality level
/// - Adapts timeout values based on quality
/// - Skips non-critical prefetching in poor conditions
///
/// - Important: Test on real devices with various network conditions
/// - Note: Prefetching is automatically disabled in very poor network conditions

import Foundation
import Kingfisher
import UIKit

/// Network quality levels based on prefetch success rates
private enum NetworkQuality {
    case excellent  // 90%+ success rate
    case good      // 70-90% success rate
    case poor      // 40-70% success rate
    case veryPoor  // <40% success rate
}

/// Instagram-level image prefetching system optimized for smooth scrolling.
///
/// Singleton instance that manages intelligent prefetching across the app.
/// Uses adaptive strategies based on context and network conditions.
final class CollectionImagePrefetcher {
    static let instance = CollectionImagePrefetcher()

    // Size limits to prevent unbounded memory growth
    private let maxCollectionsTracked = 20  // Maximum number of collections to track
    private let maxURLsPerCollection = 100  // Maximum URLs per collection per quality level

    // Prefetchers by collection ID
    private var lowPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    private var medPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    private var highPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]

    // Track prefetched URLs to support pagination (with size limits)
    private var prefetchedLowURLs: [String: Set<URL>] = [:]
    private var prefetchedMedURLs: [String: Set<URL>] = [:]
    private var prefetchedHighURLs: [String: Set<URL>] = [:]

    // Track access order for LRU eviction
    private var collectionAccessOrder: [String] = []

    // Prefetching queue to avoid blocking main thread
    private let prefetchQueue = DispatchQueue(label: "com.clique.imagePrefetcher", qos: .utility)

    // Track active prefetch operations for smarter management
    private var activePrefetchCount = 0
    private let maxConcurrentPrefetches = 2  // Reduced from 3 to prevent UI blocking

    // Network quality tracking
    private var recentPrefetchResults: [Bool] = [] // Track last 20 results
    private var networkQuality: NetworkQuality = .good
    private let maxTrackedResults = 20

    // Debounce mechanism to prevent rapid prefetch calls during scrolling
    private var prefetchDebounceTimer: Timer?
    // Use serial queue to synchronize access to pendingPrefetchOperations
    private let pendingOperationsQueue = DispatchQueue(label: "com.clique.prefetch.pending", attributes: .concurrent)
    private var _pendingPrefetchOperations: [(context: PrefetchContext, collectionId: String, images: [CollectionImage])] = []

    private init() {
        setupMemoryWarningObserver()
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        // Stop all non-critical prefetching on memory warning
        prefetchQueue.async { [weak self] in
            self?.stopAllPrefetching()
        }
    }

    // MARK: - Network Quality Monitoring

    private func updateNetworkQuality(success: Int, failed: Int) {
        let total = success + failed
        guard total > 0 else { return }

        // Record metrics
        Task {
            await CacheMetrics.shared.recordPrefetch(count: total)
        }

        // Add results to tracking array
        for _ in 0..<success {
            recentPrefetchResults.append(true)
        }
        for _ in 0..<failed {
            recentPrefetchResults.append(false)
        }

        // Keep only last N results
        if recentPrefetchResults.count > maxTrackedResults {
            recentPrefetchResults = Array(recentPrefetchResults.suffix(maxTrackedResults))
        }

        // Calculate overall success rate
        let recentSuccessRate = Double(recentPrefetchResults.filter { $0 }.count) / Double(max(1, recentPrefetchResults.count))

        // Update network quality assessment (less aggressive thresholds)
        switch recentSuccessRate {
        case 0.8...1.0:
            networkQuality = .excellent
        case 0.5..<0.8:
            networkQuality = .good
        case 0.2..<0.5:
            networkQuality = .poor
        default:
            networkQuality = .veryPoor
        }

        #if DEBUG
        if networkQuality == .poor || networkQuality == .veryPoor {
            print("⚠️ Network quality: \(networkQuality), success rate: \(Int(recentSuccessRate * 100))%")
        }
        #endif

        // Record network fetch failures
        if failed > 0 {
            Task {
                for _ in 0..<failed {
                    await CacheMetrics.shared.recordNetworkFetch(duration: 0, success: false)
                }
            }
        }
    }

    /// Skip prefetching entirely if network is too poor
    private func shouldSkipPrefetch(for context: PrefetchContext) -> Bool {
        switch (networkQuality, context) {
        case (.veryPoor, .detailView):
            // Still try for detail view even in very poor network
            return false
        case (.veryPoor, _):
            // Skip other prefetching in very poor network
            return true
        case (.poor, .backgroundRefresh):
            // Skip background refresh in poor network
            return true
        default:
            return false
        }
    }

    // MARK: - LRU Eviction and Size Management

    private func updateCollectionAccess(_ collectionId: String) {
        // Remove from current position if exists
        collectionAccessOrder.removeAll { $0 == collectionId }
        // Add to end (most recently used)
        collectionAccessOrder.append(collectionId)

        // Evict least recently used collections if over limit
        while collectionAccessOrder.count > maxCollectionsTracked {
            let evictedId = collectionAccessOrder.removeFirst()
            evictCollection(evictedId)
        }
    }

    private func evictCollection(_ collectionId: String) {
        // Stop all prefetching for this collection
        stopLowPrefetching(for: collectionId)
        stopMediumPrefetching(for: collectionId)
        stopHighPrefetching(for: collectionId)

        // Remove from URL tracking
        prefetchedLowURLs.removeValue(forKey: collectionId)
        prefetchedMedURLs.removeValue(forKey: collectionId)
        prefetchedHighURLs.removeValue(forKey: collectionId)
    }

    private func enforceURLLimit(for urls: inout Set<URL>) {
        // If URLs exceed limit, keep only the most recent ones
        if urls.count > maxURLsPerCollection {
            let urlArray = Array(urls)
            // Keep the last N URLs (most recently added)
            urls = Set(urlArray.suffix(maxURLsPerCollection))
        }
    }

    // MARK: - Smart Prefetching Based on Context

    /// Prefetch images based on context (feed, detail view, etc.)
    func prefetchForContext(_ context: PrefetchContext, collectionId: String, images: [CollectionImage]) {
        // Update LRU tracking for this collection
        updateCollectionAccess(collectionId)

        // For grid view, debounce to prevent rapid calls during scrolling
        if context == .gridView {
            // Cancel existing timer
            prefetchDebounceTimer?.invalidate()

            // Store operation (thread-safe with optimized filter)
            pendingOperationsQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }

                // Remove previous operations for this collection more efficiently
                self._pendingPrefetchOperations.removeAll { $0.collectionId == collectionId }
                // Add new operation
                self._pendingPrefetchOperations.append((context, collectionId, images))
            }

            // Schedule debounced execution
            prefetchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                // Get pending operation (thread-safe)
                self.pendingOperationsQueue.async(flags: .barrier) {
                    guard let operation = self._pendingPrefetchOperations.last else { return }
                    self._pendingPrefetchOperations.removeAll()

                    // Execute on prefetch queue
                    self.prefetchQueue.async {
                        self.executePrefetch(context: operation.context, collectionId: operation.collectionId, images: operation.images)
                    }
                }
            }
        } else {
            // Execute immediately for non-grid contexts
            executePrefetch(context: context, collectionId: collectionId, images: images)
        }
    }

    private func executePrefetch(context: PrefetchContext, collectionId: String, images: [CollectionImage]) {
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }

            // Check if we should skip prefetching based on network conditions
            if self.shouldSkipPrefetch(for: context) {
                #if DEBUG
                print("⏩ Skipping prefetch for \(context) due to poor network conditions")
                #endif
                return
            }

            switch context {
            case .feedScroll:
                // For feed scrolling, prefetch only medium quality for visible items
                self.prefetchMediumQuality(collectionId: collectionId, images: Array(images.prefix(6)))

            case .detailView:
                // For detail view, prefetch high quality for current and adjacent images
                self.prefetchHighQuality(collectionId: collectionId, images: Array(images.prefix(5)))

            case .gridView:
                // For grid view, prefetch low quality for fewer items to avoid blocking
                // Grid thumbnails should load on-demand as user scrolls
                self.prefetchLowQuality(collectionId: collectionId, images: Array(images.prefix(8)))

            case .backgroundRefresh:
                // Background refresh - prefetch medium quality for first few items
                self.prefetchMediumQuality(collectionId: collectionId, images: Array(images.prefix(3)))
            }
        }
    }

    enum PrefetchContext {
        case feedScroll
        case detailView
        case gridView
        case backgroundRefresh
    }

    // MARK: - Low Quality Prefetching
    func prefetchLowQuality(collectionId: String, images: [CollectionImage]) {
        guard activePrefetchCount < maxConcurrentPrefetches else { return }

        let allLowUrls = images.compactMap { URL(string: $0.imageUrl?.lowQualityUrl ?? "") }
        let lowQualityUrls = filterNonCachedUrlsEfficiently(allLowUrls)

        guard !lowQualityUrls.isEmpty else { return }

        let previousLowURLs = prefetchedLowURLs[collectionId] ?? []
        prefetchedLowURLs[collectionId, default: []].formUnion(lowQualityUrls)

        // Enforce size limit for this collection
        if var urls = prefetchedLowURLs[collectionId] {
            enforceURLLimit(for: &urls)
            prefetchedLowURLs[collectionId] = urls
        }

        // If all new URLs are already being prefetched, skip
        if lowQualityUrls.allSatisfy({ previousLowURLs.contains($0) }) { return }

        // Stop existing and start new prefetcher
        lowPrefetchers[collectionId]?.stop()
        activePrefetchCount += 1
        lowPrefetchers[collectionId] = createSmartPrefetcher(
            with: Array(prefetchedLowURLs[collectionId]!.prefix(6)), // Reduced from 10 to prevent blocking
            quality: .low,
            collectionId: collectionId
        )
    }

    // MARK: - Medium Quality Prefetching
    func prefetchMediumQuality(collectionId: String, images: [CollectionImage]) {
        guard activePrefetchCount < maxConcurrentPrefetches else { return }

        let allMedUrls = images.compactMap { URL(string: $0.imageUrl?.medQualityUrl ?? "") }
        let medUrls = filterNonCachedUrlsEfficiently(allMedUrls)

        guard !medUrls.isEmpty else { return }

        let previousMedURLs = prefetchedMedURLs[collectionId] ?? []
        prefetchedMedURLs[collectionId, default: []].formUnion(medUrls)

        // Enforce size limit for this collection
        if var urls = prefetchedMedURLs[collectionId] {
            enforceURLLimit(for: &urls)
            prefetchedMedURLs[collectionId] = urls
        }

        // If all new URLs are already being prefetched, skip
        if medUrls.allSatisfy({ previousMedURLs.contains($0) }) { return }

        medPrefetchers[collectionId]?.stop()
        activePrefetchCount += 1
        medPrefetchers[collectionId] = createSmartPrefetcher(
            with: Array(prefetchedMedURLs[collectionId]!.prefix(4)), // Reduced from 8 to prevent blocking
            quality: .medium,
            collectionId: collectionId
        )
    }

    // MARK: - High Quality Prefetching
    func prefetchHighQuality(collectionId: String, images: [CollectionImage]) {
        guard activePrefetchCount < maxConcurrentPrefetches else { return }

        let allHighUrls = images.compactMap { URL(string: $0.imageUrl?.highQualityUrl ?? "") }
        let highUrls = filterNonCachedUrlsEfficiently(allHighUrls)

        guard !highUrls.isEmpty else { return }

        let previousHighURLs = prefetchedHighURLs[collectionId] ?? []
        prefetchedHighURLs[collectionId, default: []].formUnion(highUrls)

        // Enforce size limit for this collection
        if var urls = prefetchedHighURLs[collectionId] {
            enforceURLLimit(for: &urls)
            prefetchedHighURLs[collectionId] = urls
        }

        // If all new URLs are already being prefetched, skip
        if highUrls.allSatisfy({ previousHighURLs.contains($0) }) { return }

        highPrefetchers[collectionId]?.stop()
        activePrefetchCount += 1
        highPrefetchers[collectionId] = createSmartPrefetcher(
            with: Array(prefetchedHighURLs[collectionId]!.prefix(3)), // Reduced from 5 to prevent blocking
            quality: .high,
            collectionId: collectionId
        )
    }

    // MARK: - Stop Prefetching
    func stopPrefetching(collectionId: String) {
        // Invalidate timer to prevent memory leak
        prefetchDebounceTimer?.invalidate()
        prefetchDebounceTimer = nil

        prefetchQueue.async { [weak self] in
            self?.stopLowPrefetching(for: collectionId)
            self?.stopMediumPrefetching(for: collectionId)
            self?.stopHighPrefetching(for: collectionId)
        }
    }

    private func stopAllPrefetching() {
        // Invalidate timer to prevent memory leak
        prefetchDebounceTimer?.invalidate()
        prefetchDebounceTimer = nil

        lowPrefetchers.values.forEach { $0.stop() }
        medPrefetchers.values.forEach { $0.stop() }
        highPrefetchers.values.forEach { $0.stop() }

        lowPrefetchers.removeAll()
        medPrefetchers.removeAll()
        highPrefetchers.removeAll()

        prefetchedLowURLs.removeAll()
        prefetchedMedURLs.removeAll()
        prefetchedHighURLs.removeAll()

        activePrefetchCount = 0
    }

    func stopLowPrefetching(for collectionId: String) {
        lowPrefetchers[collectionId]?.stop()
        lowPrefetchers.removeValue(forKey: collectionId)
        prefetchedLowURLs.removeValue(forKey: collectionId)
        activePrefetchCount = max(0, activePrefetchCount - 1)
    }

    func stopMediumPrefetching(for collectionId: String) {
        medPrefetchers[collectionId]?.stop()
        medPrefetchers.removeValue(forKey: collectionId)
        prefetchedMedURLs.removeValue(forKey: collectionId)
        activePrefetchCount = max(0, activePrefetchCount - 1)
    }

    func stopHighPrefetching(for collectionId: String) {
        highPrefetchers[collectionId]?.stop()
        highPrefetchers.removeValue(forKey: collectionId)
        prefetchedHighURLs.removeValue(forKey: collectionId)
        activePrefetchCount = max(0, activePrefetchCount - 1)
    }

    // MARK: - Private Helpers

    private func createSmartPrefetcher(with urls: [URL], quality: Quality, collectionId: String) -> Kingfisher.ImagePrefetcher {
        // Configure options based on quality level
        let processorSize: CGSize
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale

        switch quality {
        case .low:
            // Thumbnail size
            processorSize = CGSize(width: 200 * scale, height: 200 * scale)
        case .medium:
            // Half screen size
            processorSize = CGSize(width: screenSize.width * scale * 0.5, height: screenSize.height * scale * 0.5)
        case .high:
            // Full screen size with some buffer
            processorSize = CGSize(width: screenSize.width * scale * 1.2, height: screenSize.height * scale * 1.2)
        }

        // Adjust timeout based on network quality and context
        let timeoutInterval: TimeInterval = {
            switch (networkQuality, quality) {
            case (.veryPoor, _):
                return 10 // Fail fast in very poor conditions
            case (.poor, .high):
                return 15 // Reduced timeout for high quality in poor network
            case (.poor, _):
                return 12
            case (_, .low):
                return 15 // Thumbnails should load fast
            default:
                return 20 // Normal timeout for decent network
            }
        }()

        // Configure retry strategy with adaptive delays based on network quality
        let retryInterval: DelayRetryStrategy.Interval = networkQuality == .poor ? .seconds(1) : .accumulated(1)
        let retryStrategy = DelayRetryStrategy(
            maxRetryCount: networkQuality == .veryPoor ? 0 : (networkQuality == .poor ? 1 : 2),
            retryInterval: retryInterval  // Poor network: constant 1s delay, Good: 1s, 2s, 3s progressive
        )

        // Create request modifier for timeout
        let modifier = AnyModifier { request in
            var modifiedRequest = request
            modifiedRequest.timeoutInterval = timeoutInterval
            return modifiedRequest
        }

        let options: KingfisherOptionsInfo = [
            .processor(DownsamplingImageProcessor(size: processorSize)),
            .scaleFactor(scale),
            .memoryCacheExpiration(.seconds(3600)),
            .diskCacheExpiration(.days(7)),
            .backgroundDecode,
            .cacheOriginalImage,
            .callbackQueue(.dispatch(prefetchQueue)),
            .requestModifier(modifier),
            .retryStrategy(retryStrategy)
        ]

        let prefetcher = Kingfisher.ImagePrefetcher(
            urls: urls,
            options: options,
            completionHandler: { [weak self] skippedResources, failedResources, completedResources in
                DispatchQueue.main.async {
                    self?.activePrefetchCount = max(0, (self?.activePrefetchCount ?? 1) - 1)

                    // Update network quality tracking
                    self?.updateNetworkQuality(success: completedResources.count, failed: failedResources.count)

                    #if DEBUG
                    if !failedResources.isEmpty {
                        print("⚠️ Prefetch failed for \(failedResources.count) images in collection \(collectionId)")
                        // Log first error for debugging
                        if let firstFailed = failedResources.first {
                            // failedResources contains Resource objects (URLs)
                            if let url = (firstFailed as? KF.ImageResource)?.downloadURL {
                                print("   First failed URL: \(url.lastPathComponent)")
                            }
                        }
                    }
                    #endif
                }
            }
        )

        prefetcher.start()
        return prefetcher
    }

    private enum Quality {
        case low, medium, high
    }

    // MARK: - Efficient Batch Cache Checking

    private func filterNonCachedUrlsEfficiently(_ urls: [URL]) -> [URL] {
        guard !urls.isEmpty else { return [] }

        let cache = ImageCache.default
        var nonCachedUrls: [URL] = []
        nonCachedUrls.reserveCapacity(urls.count) // Pre-allocate for performance

        // Process in batches to avoid holding cache lock too long
        let batchSize = 20
        for i in stride(from: 0, to: urls.count, by: batchSize) {
            let endIndex = min(i + batchSize, urls.count)
            let batch = Array(urls[i..<endIndex])

            autoreleasepool {
                for url in batch {
                    let key = url.absoluteString
                    // Quick check without loading image data
                    if !cache.isCached(forKey: key, processorIdentifier: "") {
                        nonCachedUrls.append(url)
                    }
                }
            }
        }

        return nonCachedUrls
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
