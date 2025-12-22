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
        // Trigger lifecycle manager initialization on main thread
        // This ensures notification observers are registered as early as possible
        // The manager is accessed via its singleton, which will initialize synchronously
        // when first accessed from main thread
        Task { @MainActor in
            _ = ImageCacheLifecycleManager.shared
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

    /// Performs periodic cleanup of expired cache entries.
    /// Intended to be called from timer or other periodic mechanisms.
    func performCleanup() {
        cleanupIfNeeded()
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

/// Lifecycle manager for image cache cleanup and memory management.
///
/// This class manages the timer and notification observers for the singleton cache manager.
/// Even though the cache manager is a singleton with app lifetime, we store observer tokens
/// as a best practice for proper resource management.
@MainActor
private final class ImageCacheLifecycleManager {
    static let shared = ImageCacheLifecycleManager()

    private var cleanupTimer: Timer?
    private var notificationTokens: [NSObjectProtocol] = []

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        let manager = GenericAsyncImageCacheManager.shared

        // Invalidate existing timer before creating new one
        cleanupTimer?.invalidate()

        // Periodic cleanup timer
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: ImageCacheConfig.cleanupInterval, repeats: true) { _ in
            Task {
                await manager.performCleanup()
            }
        }

        // Store notification observer tokens for proper cleanup
        let backgroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await manager.clearCache()
            }
        }
        notificationTokens.append(backgroundToken)

        let memoryWarningToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await manager.handleMemoryPressure()
            }
        }
        notificationTokens.append(memoryWarningToken)
    }

    deinit {
        cleanupTimer?.invalidate()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
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
///   - context: Loading context (list/grid/detail/hero) for optimal strategy
///   - performanceMode: Use lightweight mode for grids (default: false, auto-enabled for list/grid contexts)
///   - content: View builder for the loaded image
///   - placeholder: View to show while loading
struct GenericAsyncImage<Content: View, Placeholder: View>: View {
    let urls: PhotoUrls?
    var quality: ImageQuality
    var shouldFixSize: Bool = true
    var context: ImageLoadingContext = .detail
    var performanceMode: Bool = false  // Automatically enabled for list/grid contexts

    let content: (KFImage) -> Content
    @ViewBuilder var placeholder: Placeholder

    /// Computed performance mode based on context.
    /// List and grid contexts automatically use performance mode for better scrolling.
    private var effectivePerformanceMode: Bool {
        performanceMode || context == .list || context == .grid
    }

    /// Effective context considering force preload flag from timeout retry.
    /// If we've detected a stuck placeholder, force preload even in detail context.
    private var effectiveContext: ImageLoadingContext {
        forcePreload ? .list : context
    }


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

    @State private var loadingState: ImageLoadingState
    @State private var cacheCheckCompleted = false
    @State private var imageLoadTasks: Set<AnyCancellable> = []
    @State private var retryCount: [String: Int] = [:]

    // Smart retry mechanism for stuck placeholders
    @State private var loadingTimeoutTask: Task<Void, Never>?
    @State private var hasAttemptedRetry = false
    @State private var forcePreload = false

    // Cache status for immediate display
    // Initialize with synchronous check for low quality to prevent placeholder flash
    @State private var hasCachedLow: Bool
    @State private var hasCachedMedium = false
    @State private var hasCachedHigh = false

    private let cacheManager = GenericAsyncImageCacheManager.shared

    init(urls: PhotoUrls?, quality: ImageQuality, shouldFixSize: Bool = true, context: ImageLoadingContext = .detail, performanceMode: Bool = false, @ViewBuilder content: @escaping (KFImage) -> Content, @ViewBuilder placeholder: () -> Placeholder) {
        self.urls = urls
        self.quality = quality
        self.shouldFixSize = shouldFixSize
        self.context = context
        self.performanceMode = performanceMode
        self.content = content
        self.placeholder = placeholder()

        // Synchronous cache check for low quality on init to prevent placeholder flash
        // This ensures we can show the cached thumbnail immediately while loading high quality
        let cachedLow: Bool
        if let lowUrl = urls?.lowQualityUrl {
            cachedLow = GenericAsyncImageCacheManager.shared.checkCacheSync(for: lowUrl)
        } else {
            cachedLow = false
        }
        self._hasCachedLow = State(initialValue: cachedLow)

        // Set initial loading state based on cache check to ensure correct rendering on first frame
        let initialState: ImageLoadingState
        switch quality {
        case .low:
            initialState = cachedLow ? .showingLow : .loadingLow
        case .medium:
            initialState = cachedLow ? .loadingMedium(fallback: .low) : .loadingMedium(fallback: nil)
        case .high:
            initialState = cachedLow ? .loadingHigh(fallback: .low) : .loadingHigh(fallback: nil)
        }
        self._loadingState = State(initialValue: initialState)
    }
    private let maxRetries = 2

    /// Network-adaptive timeout for placeholder detection
    /// - WiFi/Ethernet: 750ms - Fast networks should load quickly
    /// - Cellular: 2000ms - Accommodate variable cellular speeds (3G/4G/5G)
    /// - Unknown: 1500ms - Middle ground for uncertain conditions
    private var placeholderTimeout: TimeInterval {
        switch NetworkMonitor.shared.connectionType {
        case .wifi, .ethernet:
            return 0.75
        case .cellular:
            return 2.0
        case .unknown:
            return 1.5
        }
    }

    // MARK: - Computed Properties

    private var shouldShowPlaceholder: Bool {
        !loadingState.isShowingAny && !hasCachedLow && !hasCachedMedium && !hasCachedHigh
    }

    private var shouldShowLowQuality: Bool {
        switch loadingState {
        case .showingLow, .loadingLow, .loadingMedium(fallback: .low), .loadingHigh(fallback: .low):
            return true
        case .showingHigh, .showingMedium:
            // Don't show low when higher quality is already showing
            return false
        default:
            return hasCachedLow && !loadingState.isShowingAny
        }
    }

    private var shouldShowMediumQuality: Bool {
        switch loadingState {
        case .showingMedium, .loadingMedium, .loadingHigh(fallback: .medium):
            return true
        case .showingHigh:
            // Don't show medium when high is already showing
            return false
        default:
            // Only show cached medium if medium quality was explicitly requested
            // Don't show medium when high quality is requested (skip medium tier)
            return hasCachedMedium && !loadingState.isShowingAny && quality == .medium
        }
    }

    private var shouldShowHighQuality: Bool {
        switch loadingState {
        case .showingHigh, .loadingHigh:
            return true
        default:
            return false
        }
    }


    var body: some View {
        ZStack {
            if effectivePerformanceMode {
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
            // Loading state is already set in init based on synchronous cache check
            // Continue with async cache check for higher qualities (med/high)
            Task.detached(priority: .userInitiated) {
                await self.performAsyncCacheCheck()
                await MainActor.run {
                    if !self.cacheCheckCompleted {
                        Task { await self.determineInitialState() }
                    }
                }
            }

            // Start smart timeout detection for stuck placeholders
            startPlaceholderTimeoutDetection()
        }
        .onDisappear {
            // Cancel timeout task when view disappears
            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = nil
        }
        .onChange(of: urls) { oldUrls, newUrls in
            guard oldUrls != newUrls else { return }

            // Reset when URLs change
            cacheCheckCompleted = false
            retryCount.removeAll()
            hasAttemptedRetry = false
            forcePreload = false

            // Cancel existing timeout
            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = nil

            // Synchronous cache check for low quality to prevent placeholder flash on URL change
            let cachedLow: Bool
            if let lowUrl = newUrls?.lowQualityUrl {
                cachedLow = cacheManager.checkCacheSync(for: lowUrl)
            } else {
                cachedLow = false
            }
            hasCachedLow = cachedLow
            hasCachedMedium = false
            hasCachedHigh = false

            // Set loading state based on synchronous cache check (same logic as init)
            switch quality {
            case .low:
                loadingState = cachedLow ? .showingLow : .loadingLow
            case .medium:
                loadingState = cachedLow ? .loadingMedium(fallback: .low) : .loadingMedium(fallback: nil)
            case .high:
                loadingState = cachedLow ? .loadingHigh(fallback: .low) : .loadingHigh(fallback: nil)
            }

            // Check cache for new URLs asynchronously for higher qualities
            Task.detached(priority: .userInitiated) {
                await self.performAsyncCacheCheck()
                await MainActor.run {
                    if !self.cacheCheckCompleted {
                        Task { await self.determineInitialState() }
                    }
                }
            }

            // Restart timeout detection
            startPlaceholderTimeoutDetection()
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

    // MARK: - Standard Mode View (Conditional Rendering)

    @ViewBuilder
    private var standardModeView: some View {
        // Placeholder layer - only shown when no image is visible
        if shouldShowPlaceholder {
            placeholder
                .allowsHitTesting(false)
                .transition(.opacity)
        }

        // Conditional image layers - only create/download when needed
        // This prevents unnecessary downloads by not initializing hidden KFImage views

        // Low quality layer
        if shouldShowLowQuality {
            qualityImageView(
                url: urls?.lowQualityUrl,
                shouldFade: false, // Never fade fallback
                onSuccess: { handleImageLoaded(.low) },
                onFailure: { handleImageFailed(urls?.lowQualityUrl) }
            )
            .allowsHitTesting(false) // Never allow interaction on background layers
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }

        // Medium quality layer
        if shouldShowMediumQuality {
            qualityImageView(
                url: urls?.medQualityUrl,
                shouldFade: loadingState == .loadingMedium(fallback: nil), // Only fade when directly requested
                onSuccess: { handleImageLoaded(.medium) },
                onFailure: { handleImageFailed(urls?.medQualityUrl) }
            )
            .allowsHitTesting(false) // Never allow interaction on background layers
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }

        // High quality layer
        if shouldShowHighQuality {
            qualityImageView(
                url: urls?.highQualityUrl,
                shouldFade: loadingState == .loadingHigh(fallback: nil), // Only fade when directly requested
                onSuccess: { handleImageLoaded(.high) },
                onFailure: { handleImageFailed(urls?.highQualityUrl) }
            )
            .allowsHitTesting(shouldShowHighQuality) // Only top layer can receive touches
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }
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
                .kfModifiers(shouldFade: shouldFade, context: effectiveContext)
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

        // Mark cache check as completed to prevent duplicate checks
        cacheCheckCompleted = true
    }

    private func updateStateForCachedContent() {
        switch quality {
        case .low:
            if hasCachedLow {
                loadingState = .showingLow
            } else {
                loadingState = .loadingLow
            }
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
            // Match both .loadingMedium (no fallback) and .loadingMedium(fallback: _)
            if case .loadingMedium = loadingState {
                loadingState = .showingMedium
            }
        case .high:
            // Match both .loadingHigh (no fallback) and .loadingHigh(fallback: _)
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

    // MARK: - Smart Timeout Detection

    /// Starts monitoring for stuck placeholders and automatically retries with preloading if detected.
    ///
    /// This function implements intelligent failure detection by:
    /// 1. Waiting for a timeout period (2.5 seconds)
    /// 2. Checking if image is still showing placeholder
    /// 3. If stuck, forcing preload mode and triggering cache clear + retry
    ///
    /// This solves the iOS 16-18 List lifecycle bug where onAppear doesn't fire reliably,
    /// causing images to never start loading in certain contexts.
    private func startPlaceholderTimeoutDetection() {
        // Cancel any existing timeout
        loadingTimeoutTask?.cancel()

        loadingTimeoutTask = Task {
            // Wait for timeout period
            try? await Task.sleep(for: .seconds(placeholderTimeout))

            // Check if still showing placeholder and haven't retried yet
            guard !Task.isCancelled,
                  !hasAttemptedRetry,
                  !loadingState.isShowingAny,
                  urls != nil else {
                return
            }

            // Image is stuck as placeholder - force aggressive retry
            await performSmartRetry()
        }
    }

    /// Performs an intelligent retry by enabling preload mode and refreshing the image.
    @MainActor
    private func performSmartRetry() {
        hasAttemptedRetry = true
        forcePreload = true

        // Reset loading state to trigger fresh load with preload enabled
        loadingState = .idle
        cacheCheckCompleted = false
        retryCount.removeAll()

        // Clear any potentially stale cache entries
        if let lowUrl = urls?.lowQualityUrl {
            KingfisherManager.shared.cache.removeImage(forKey: lowUrl)
        }

        // Trigger fresh async cache check with new preload context
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
