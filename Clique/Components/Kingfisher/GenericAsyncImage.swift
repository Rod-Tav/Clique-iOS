//
//  GenericAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/13/25.
//

/// High-performance image loading system with Instagram-level optimizations.
///
/// ## Architecture Overview
///
/// The image loading system consists of three main components:
/// - **GenericAsyncImage**: The main view component with dual-mode support (performance/standard)
/// - **GenericAsyncImageCacheManager**: Instance-based cache for synchronous checks
/// - **CollectionImagePrefetcher**: Intelligent prefetching with network adaptation
///
/// ## Caching Strategy
///
/// ### Multi-Level Cache
/// ```
/// Request Flow:
/// 1. Synchronous Memory Check (instant)
/// 2. TTL-based Result Cache (2 seconds)
/// 3. Kingfisher Memory Cache (15-20% RAM)
/// 4. Kingfisher Disk Cache (1-2GB)
/// 5. Network Fetch (if needed)
/// ```
///
/// ### Cache Sizes
/// - **Memory**: 15-20% of device RAM (matching Instagram)
/// - **Disk**: 2GB for iPad, 1GB for iPhone
/// - **Result Cache**: 500 entries with 2-second TTL
///
/// ## Performance Modes
///
/// ### Performance Mode (Lightweight)
/// - Minimal state changes to prevent recomposition
/// - Direct Kingfisher integration
/// - Best for grids and lists with many items
/// - No progressive loading
///
/// ### Standard Mode (Full Features)
/// - Progressive quality loading (low → medium → high)
/// - Smooth transitions between qualities
/// - Retry mechanism with error states
/// - Best for detail views and hero images
///
/// ## Network Resilience
///
/// ### Adaptive Quality Detection
/// ```swift
/// // Quality thresholds (success rate):
/// Excellent: 80-100% → Full prefetching
/// Good: 50-80% → Reduced prefetching
/// Poor: 20-50% → Minimal prefetching
/// Very Poor: 0-20% → Skip non-critical
/// ```
///
/// ### Retry Strategy
/// - User-visible images: 2 retries with progressive delays
/// - Prefetch images: Fail-fast with 10-20s timeout
/// - Network quality affects retry behavior
///
/// ## Memory Management
///
/// ### Pressure Handling
/// - Monitors system memory warnings
/// - Cancels prefetch operations under pressure
/// - Clears cache on app background
/// - Auto-cleanup every 30 seconds
///
/// ### Thread Safety
/// - @MainActor for UI updates
/// - Background queues for cache checks
/// - Task cancellation for race prevention
/// - UUID-based request tracking
///
/// ## Usage Examples
///
/// ### Performance Mode (Grid)
/// ```swift
/// GenericAsyncImage(
///     urls: image.urls,
///     quality: .low,
///     performanceMode: true
/// ) { kfImage in
///     kfImage
///         .resizable()
///         .aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Color.gray.opacity(0.1)
/// }
/// ```
///
/// ### Standard Mode (Detail)
/// ```swift
/// GenericAsyncImage(
///     urls: image.urls,
///     quality: .high,
///     performanceMode: false
/// ) { kfImage in
///     kfImage
///         .resizable()
///         .aspectRatio(contentMode: .fit)
/// } placeholder: {
///     ProgressView()
/// }
/// ```
///
/// ## Performance Metrics
///
/// Track performance with ``CacheMetrics``:
/// - Cache hit rate
/// - Network success rate
/// - Prefetch effectiveness
/// - Average fetch times
///
/// ## Best Practices
///
/// 1. Use performance mode for lists/grids
/// 2. Use standard mode for detail views
/// 3. Prefetch contextually (feed vs detail)
/// 4. Monitor metrics in debug builds
/// 5. Clear cache on memory warnings
///
/// - Important: Always test on real devices for accurate performance
/// - Note: Simulator performance differs significantly from devices

import SwiftUI
import Kingfisher
import Combine

/// Configuration constants for image caching system
struct ImageCacheConfig {
    static let cacheResultTTL: TimeInterval = 2.0 // 2 seconds TTL for result cache
    static let maxCacheSize = 500 // Maximum cached results
    static let cleanupInterval: TimeInterval = 30.0 // Cleanup interval in seconds
    static let maxConcurrentChecks = 10 // Maximum concurrent cache checks
}

/// Instance-based cache manager for synchronous cache checking.
///
/// Provides instant cache hit detection to eliminate placeholder flash.
/// Uses TTL-based caching with automatic cleanup and race condition prevention.
/// Thread-safe using Swift actor isolation (iOS 17+).
actor GenericAsyncImageCacheManager {
    static let shared = GenericAsyncImageCacheManager()

    // Actor-isolated state - automatically thread-safe
    private var cacheCheckResults: [String: (Bool, Date)] = [:]
    private var pendingChecks: [String: Task<Bool, Never>] = [:]
    private var lastCleanupTime: Date = Date()
    private var isCleaningUp: Bool = false

    private init() {
        // Setup notifications on main actor
        Task { @MainActor in
            setupNotificationObservers()
        }
    }

    func getCachedResult(for url: String) -> Bool? {
        // Lazy cleanup - only when needed and not too frequently
        cleanupIfNeeded()

        if let (cachedResult, timestamp) = cacheCheckResults[url],
           Date().timeIntervalSince(timestamp) < ImageCacheConfig.cacheResultTTL {
            return cachedResult
        }
        return nil
    }

    func setCachedResult(for url: String, result: Bool) {
        // Prevent unbounded growth
        if cacheCheckResults.count >= ImageCacheConfig.maxCacheSize {
            let now = Date()
            cacheCheckResults = cacheCheckResults.filter {
                now.timeIntervalSince($0.value.1) < ImageCacheConfig.cacheResultTTL
            }
        }

        cacheCheckResults[url] = (result, Date())
        pendingChecks[url] = nil
    }

    // Get or create a cache check task to prevent race conditions
    func getCacheCheckTask(for url: String) -> Task<Bool, Never>? {
        return pendingChecks[url]
    }

    func setPendingCacheCheck(for url: String, task: Task<Bool, Never>) {
        pendingChecks[url] = task
    }

    func removePendingCheck(for url: String) {
        pendingChecks[url] = nil
    }

    private func cleanupIfNeeded() {
        guard !isCleaningUp else { return }

        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) > ImageCacheConfig.cleanupInterval else { return }

        isCleaningUp = true

        // Perform cleanup inline - actor ensures thread safety
        cacheCheckResults = cacheCheckResults.filter {
            now.timeIntervalSince($0.value.1) < ImageCacheConfig.cacheResultTTL
        }
        lastCleanupTime = now
        isCleaningUp = false
    }

    func handleMemoryPressure() {
        // Reduce cache size by 50% on memory warning
        let entriesToKeep = cacheCheckResults.count / 2
        let sortedEntries = cacheCheckResults.sorted { $0.value.1 > $1.value.1 }
        cacheCheckResults = Dictionary(uniqueKeysWithValues: Array(sortedEntries.prefix(entriesToKeep)))
    }

    func clearCache() {
        cacheCheckResults.removeAll()
        pendingChecks.removeAll()
    }

    // Synchronous cache check for immediate display
    nonisolated func checkCacheSync(for urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let resource = KF.ImageResource(downloadURL: url)
        return KingfisherManager.shared.cache.isCached(forKey: resource.cacheKey) ||
               KingfisherManager.shared.cache.isCached(forKey: urlString)
    }
}

// MARK: - MainActor Setup
@MainActor
private func setupNotificationObservers() {
    let manager = GenericAsyncImageCacheManager.shared

    // Periodic cleanup timer
    Timer.scheduledTimer(withTimeInterval: ImageCacheConfig.cleanupInterval, repeats: true) { _ in
        Task {
            _ = await manager.getCachedResult(for: "") // Triggers cleanupIfNeeded
        }
    }

    // Clear cache when app backgrounds
    NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
    ) { _ in
        Task {
            await manager.clearCache()
        }
    }

    // Handle memory warnings
    NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { _ in
        Task {
            await manager.handleMemoryPressure()
        }
    }
}

/// High-performance async image view with dual-mode support.
///
/// Provides Instagram-level image loading performance with adaptive strategies
/// based on context (grid vs detail) and network conditions.
///
/// - Parameters:
///   - urls: Photo URLs for different quality levels
///   - quality: Target quality level to load
///   - shouldFixSize: Whether to fix size for layout stability
///   - loadingBug: Legacy compatibility flag
///   - performanceMode: Use lightweight mode for grids (default: false)
///   - content: View builder for the loaded image
///   - placeholder: View to show while loading
struct GenericAsyncImage<Content: View, Placeholder: View>: View {
    let urls: PhotoUrls?
    var quality: ImageQuality
    var shouldFixSize: Bool = true
    var loadingBug: Bool = false
    var performanceMode: Bool = false  // New parameter for lightweight mode

    let content: (KFImage) -> Content
    @ViewBuilder var placeholder: Placeholder


    // MARK: - Simplified State Machine

    enum ImageLoadingState: Equatable {
        case idle
        case loadingLow
        case showingLow
        case loadingMedium(fallback: ImageQuality?)
        case showingMedium
        case loadingHigh(fallback: ImageQuality?)
        case showingHigh
        case failed

        var isShowingAny: Bool {
            switch self {
            case .showingLow, .showingMedium, .showingHigh:
                return true
            default:
                return false
            }
        }
    }

    @State private var loadingState: ImageLoadingState = .idle
    @State private var cacheCheckCompleted = false
    @State private var imageLoadTasks: Set<AnyCancellable> = []
    @State private var retryCount: [String: Int] = [:]

    // Cache status for immediate display
    @State private var hasCachedLow = false
    @State private var hasCachedMedium = false
    @State private var hasCachedHigh = false

    private let cacheManager = GenericAsyncImageCacheManager.shared
    private let maxRetries = 2

    // MARK: - Computed Properties

    private var shouldShowPlaceholder: Bool {
        !loadingState.isShowingAny && !hasCachedLow && !hasCachedMedium && !hasCachedHigh
    }

    private var shouldShowLowQuality: Bool {
        switch loadingState {
        case .showingLow, .loadingMedium(fallback: .low), .loadingHigh(fallback: .low):
            return true
        default:
            return hasCachedLow && !loadingState.isShowingAny
        }
    }

    private var shouldShowMediumQuality: Bool {
        switch loadingState {
        case .showingMedium, .loadingHigh(fallback: .medium):
            return true
        default:
            return hasCachedMedium && !loadingState.isShowingAny
        }
    }

    private var shouldShowHighQuality: Bool {
        loadingState == .showingHigh
    }


    var body: some View {
        ZStack {
            if performanceMode {
                // Performance mode: Single layer approach for fast scrolling
                performanceModeView
            } else {
                // Standard mode: Multi-layer approach with smooth transitions
                standardModeView
            }

            // Error state with retry
            if loadingState == .failed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Button("Retry") {
                        retryCount.removeAll()
                        loadingState = .idle
                        Task {
                            await determineInitialState()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            }
        }
        .fixedSize(horizontal: shouldFixSize, vertical: shouldFixSize)
        .onAppear {
            // Skip synchronous cache check - do everything async
            Task.detached(priority: .userInitiated) {
                await self.performAsyncCacheCheck()
                await MainActor.run {
                    if !self.cacheCheckCompleted {
                        Task { await self.determineInitialState() }
                    }
                }
            }
        }
        .onChange(of: urls) { oldUrls, newUrls in
            guard oldUrls != newUrls else { return }

            // Reset when URLs change
            cacheCheckCompleted = false
            retryCount.removeAll()
            loadingState = .idle

            // Check cache for new URLs asynchronously
            Task.detached(priority: .userInitiated) {
                await self.performAsyncCacheCheck()
                await MainActor.run {
                    if !self.cacheCheckCompleted {
                        Task { await self.determineInitialState() }
                    }
                }
            }
        }
    }

    // MARK: - Performance Mode View (Single Layer)

    @ViewBuilder
    private var performanceModeView: some View {
        // Determine which URL to load based on quality
        let targetUrl: String? = {
            switch quality {
            case .low:
                return urls?.lowQualityUrl
            case .medium:
                return urls?.medQualityUrl ?? urls?.lowQualityUrl
            case .high:
                return urls?.highQualityUrl ?? urls?.medQualityUrl ?? urls?.lowQualityUrl
            }
        }()

        // In performance mode, show placeholder until image loads
        if let url = targetUrl {
            qualityImageView(
                url: url,
                shouldFade: false,  // No fade in performance mode
                onSuccess: {
                    switch quality {
                    case .low: handleImageLoaded(.low)
                    case .medium: handleImageLoaded(.medium)
                    case .high: handleImageLoaded(.high)
                    }
                },
                onFailure: { handleImageFailed(url) }
            )
        } else {
            // No URL available, show placeholder
            placeholder
        }
    }

    // MARK: - Standard Mode View (Multi-Layer)

    @ViewBuilder
    private var standardModeView: some View {
        // Placeholder layer
        placeholder
            .opacity(shouldShowPlaceholder ? 1 : 0)
            .allowsHitTesting(false)

        // All image layers persistent - controlled by opacity
        // Low quality layer
        qualityImageView(
            url: urls?.lowQualityUrl,
            shouldFade: false, // Never fade fallback
            onSuccess: { handleImageLoaded(.low) },
            onFailure: { handleImageFailed(urls?.lowQualityUrl) }
        )
        .opacity(shouldShowLowQuality ? 1 : 0)
        .allowsHitTesting(false) // Never allow interaction on background layers
        .animation(.easeInOut(duration: 0.15), value: shouldShowLowQuality)

        // Medium quality layer
        qualityImageView(
            url: urls?.medQualityUrl,
            shouldFade: loadingState == .loadingMedium(fallback: nil), // Only fade when directly requested
            onSuccess: { handleImageLoaded(.medium) },
            onFailure: { handleImageFailed(urls?.medQualityUrl) }
        )
        .opacity(shouldShowMediumQuality ? 1 : 0)
        .allowsHitTesting(false) // Never allow interaction on background layers
        .animation(.easeInOut(duration: 0.15), value: shouldShowMediumQuality)

        // High quality layer
        qualityImageView(
            url: urls?.highQualityUrl,
            shouldFade: loadingState == .loadingHigh(fallback: nil), // Only fade when directly requested
            onSuccess: { handleImageLoaded(.high) },
            onFailure: { handleImageFailed(urls?.highQualityUrl) }
        )
        .opacity(shouldShowHighQuality ? 1 : 0)
        .allowsHitTesting(shouldShowHighQuality) // Only top layer can receive touches
        .animation(.easeInOut(duration: 0.15), value: shouldShowHighQuality)
    }

    // MARK: - Helper Methods

    @ViewBuilder
    private func qualityImageView(
        url: String?,
        shouldFade: Bool,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping () -> Void
    ) -> some View {
        if let url = url {
            content(KFImage(urlFor(url))
                .kfModifiers(shouldFade: shouldFade, loadingBug: loadingBug)
                .onSuccess { _ in onSuccess() }
                .onFailure { _ in onFailure() }
            )
        } else {
            Color.clear
        }
    }

    // Async cache check to avoid main thread blocking
    @MainActor
    private func performAsyncCacheCheck() async {
        // Reset cache states
        hasCachedLow = false
        hasCachedMedium = false
        hasCachedHigh = false

        // Check cache asynchronously based on quality needed
        switch quality {
        case .low:
            if let low = urls?.lowQualityUrl {
                hasCachedLow = await checkCacheAsync(for: low)
            }
        case .medium:
            if let low = urls?.lowQualityUrl {
                hasCachedLow = await checkCacheAsync(for: low)
            }
            if let med = urls?.medQualityUrl {
                hasCachedMedium = await checkCacheAsync(for: med)
            }
        case .high:
            // For high quality, check all in parallel
            async let lowCheck: Bool = {
                if let url = urls?.lowQualityUrl {
                    return await checkCacheAsync(for: url)
                }
                return false
            }()
            async let medCheck: Bool = {
                if let url = urls?.medQualityUrl {
                    return await checkCacheAsync(for: url)
                }
                return false
            }()
            async let highCheck: Bool = {
                if let url = urls?.highQualityUrl {
                    return await checkCacheAsync(for: url)
                }
                return false
            }()

            hasCachedLow = await lowCheck
            hasCachedMedium = await medCheck
            hasCachedHigh = await highCheck
        }

        // Set initial state based on cached content
        updateStateForCachedContent()
    }

    private func updateStateForCachedContent() {
        switch quality {
        case .low:
            if hasCachedLow {
                loadingState = .showingLow
            }
        case .medium:
            if hasCachedMedium {
                loadingState = .showingMedium
            } else if hasCachedLow {
                loadingState = .loadingMedium(fallback: .low)
            }
        case .high:
            if hasCachedHigh {
                loadingState = .showingHigh
            } else if hasCachedMedium {
                loadingState = .loadingHigh(fallback: .medium)
            } else if hasCachedLow {
                loadingState = .loadingHigh(fallback: .low)
            }
        }
    }

    @MainActor
    private func determineInitialState() async {
        guard !cacheCheckCompleted else { return }
        cacheCheckCompleted = true

        // Async cache verification (more thorough)
        let urls = self.urls

        async let highCached: Bool = {
            if let url = urls?.highQualityUrl {
                return await checkCacheAsync(for: url)
            }
            return false
        }()

        async let mediumCached: Bool = {
            if let url = urls?.medQualityUrl {
                return await checkCacheAsync(for: url)
            }
            return false
        }()

        async let lowCached: Bool = {
            if let url = urls?.lowQualityUrl {
                return await checkCacheAsync(for: url)
            }
            return false
        }()

        hasCachedHigh = await highCached
        hasCachedMedium = await mediumCached
        hasCachedLow = await lowCached

        // Update state based on quality and cache status
        switch quality {
        case .low:
            loadingState = hasCachedLow ? .showingLow : .loadingLow

        case .medium:
            if hasCachedMedium {
                loadingState = .showingMedium
            } else if hasCachedLow {
                loadingState = .loadingMedium(fallback: .low)
            } else {
                loadingState = .loadingMedium(fallback: nil)
            }

        case .high:
            if hasCachedHigh {
                loadingState = .showingHigh
            } else if hasCachedMedium {
                loadingState = .loadingHigh(fallback: .medium)
            } else if hasCachedLow {
                loadingState = .loadingHigh(fallback: .low)
            } else {
                loadingState = .loadingHigh(fallback: nil)
            }
        }
    }

    private func checkCacheAsync(for urlString: String) async -> Bool {
        // Check cached result first
        if let cachedResult = await cacheManager.getCachedResult(for: urlString) {
            // Record metrics for cached result
            Task {
                if cachedResult {
                    await CacheMetrics.shared.recordCacheHit()
                } else {
                    await CacheMetrics.shared.recordCacheMiss()
                }
            }
            return cachedResult
        }

        // Check for existing pending operation to prevent race conditions
        if let existingTask = await cacheManager.getCacheCheckTask(for: urlString) {
            return await existingTask.value
        }

        guard let url = URL(string: urlString) else { return false }

        // Create and store task to prevent duplicate checks
        let task = Task<Bool, Never> {
            let resource = KF.ImageResource(downloadURL: url)
            let cache = KingfisherManager.shared.cache
            // Simplified async cache check without unnecessary continuation
            return await Task.detached(priority: .userInitiated) {
                cache.isCached(forKey: resource.cacheKey) || cache.isCached(forKey: urlString)
            }.value
        }

        await cacheManager.setPendingCacheCheck(for: urlString, task: task)

        let result = await task.value
        // Record metrics
        Task {
            if result {
                await CacheMetrics.shared.recordCacheHit()
            } else {
                await CacheMetrics.shared.recordCacheMiss()
            }
        }
        // Cache the result
        await cacheManager.setCachedResult(for: urlString, result: result)
        return result
    }

    private func handleImageLoaded(_ quality: ImageQuality) {
        switch quality {
        case .low:
            if case .loadingLow = loadingState {
                loadingState = .showingLow
            }
        case .medium:
            if case .loadingMedium = loadingState {
                loadingState = .showingMedium
            }
        case .high:
            if case .loadingHigh = loadingState {
                loadingState = .showingHigh
            }
        }
    }

    private func handleImageFailed(_ url: String?) {
        guard let url = url else { return }

        // Increment retry count
        let currentRetries = retryCount[url, default: 0]
        retryCount[url] = currentRetries + 1

        // Check if all qualities have failed max retries
        let allFailed = [urls?.lowQualityUrl, urls?.medQualityUrl, urls?.highQualityUrl]
            .compactMap { $0 }
            .allSatisfy { retryCount[$0, default: 0] >= maxRetries }

        if allFailed {
            loadingState = .failed
        }
    }
}
