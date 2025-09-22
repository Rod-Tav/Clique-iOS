//
//  GenericAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/13/25.
//

import SwiftUI
import Kingfisher
import Combine

// Instance-based cache manager for GenericAsyncImage cache check results
@MainActor
final class GenericAsyncImageCacheManager: ObservableObject {
    static let shared = GenericAsyncImageCacheManager()

    private var cacheCheckResults: [String: (Bool, Date)] = [:]
    private var pendingChecks: [String: Task<Bool, Never>] = [:] // Prevent race conditions
    private let cacheResultTTL: TimeInterval = 2.0 // 2 seconds TTL
    private let maxCacheSize = 100 // Prevent unbounded growth
    private var lastCleanupTime: Date = Date()
    private let cleanupInterval: TimeInterval = 30.0 // Cleanup every 30 seconds
    private var cleanupTimer: Timer? // Store timer reference for proper cleanup

    private init() {
        setupCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    func getCachedResult(for url: String) -> Bool? {
        // Lazy cleanup - only when needed and not too frequently
        cleanupIfNeeded()

        if let (cachedResult, timestamp) = cacheCheckResults[url],
           Date().timeIntervalSince(timestamp) < cacheResultTTL {
            return cachedResult
        }
        return nil
    }

    func setCachedResult(for url: String, result: Bool) {
        // Prevent unbounded growth
        if cacheCheckResults.count >= maxCacheSize {
            cleanupExpiredEntries()
        }

        cacheCheckResults[url] = (result, Date())
        pendingChecks[url] = nil // Remove from pending after completion
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
        let now = Date()
        if now.timeIntervalSince(lastCleanupTime) > cleanupInterval {
            cleanupExpiredEntries()
            lastCleanupTime = now
        }
    }

    private func cleanupExpiredEntries() {
        let now = Date()
        cacheCheckResults = cacheCheckResults.filter {
            now.timeIntervalSince($0.value.1) < cacheResultTTL
        }
    }

    private func setupCleanupTimer() {
        // Store timer reference for proper lifecycle management
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredEntries()
            }
        }

        // Clear cache when app backgrounds to free memory
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearCache()
            }
        }
    }

    // Clear cache when app backgrounds to free memory
    func clearCache() {
        cacheCheckResults.removeAll()
        pendingChecks.removeAll() // Clear pending operations too
    }

    // Synchronous cache check for immediate display
    func checkCacheSync(for urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let resource = KF.ImageResource(downloadURL: url)
        return KingfisherManager.shared.cache.isCached(forKey: resource.cacheKey) ||
               KingfisherManager.shared.cache.isCached(forKey: urlString)
    }
}

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
    @State private var cacheTasks: [String: Task<Bool, Never>] = [:]
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
            cacheTasks.values.forEach { $0.cancel() }
            cacheTasks.removeAll()
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
        .onDisappear {
            // Cancel pending cache tasks
            cacheTasks.values.forEach { $0.cancel() }
            cacheTasks.removeAll()
        }
    }

    // MARK: - Performance Mode View (Single Layer)

    @ViewBuilder
    private var performanceModeView: some View {
        // In performance mode, show placeholder or the target quality image only
        if shouldShowPlaceholder && !hasCachedHigh && !hasCachedMedium && !hasCachedLow {
            placeholder
        } else {
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

            qualityImageView(
                url: targetUrl,
                shouldFade: false,  // No fade in performance mode
                onSuccess: {
                    switch quality {
                    case .low: handleImageLoaded(.low)
                    case .medium: handleImageLoaded(.medium)
                    case .high: handleImageLoaded(.high)
                    }
                },
                onFailure: { handleImageFailed(targetUrl) }
            )
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
        if let cachedResult = cacheManager.getCachedResult(for: urlString) {
            return cachedResult
        }

        // Check for existing pending operation to prevent race conditions
        if let existingTask = cacheTasks[urlString] {
            return await existingTask.value
        }

        guard let url = URL(string: urlString) else { return false }

        // Create and store task to prevent duplicate checks
        let task = Task<Bool, Never> {
            let resource = KF.ImageResource(downloadURL: url)
            let cache = KingfisherManager.shared.cache
            return await withCheckedContinuation { continuation in
                // Check cache on background queue to avoid main thread blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    let isCached = cache.isCached(forKey: resource.cacheKey) ||
                                  cache.isCached(forKey: urlString)
                    continuation.resume(returning: isCached)
                }
            }
        }

        cacheTasks[urlString] = task
        let result = await task.value

        // Cache the result
        cacheManager.setCachedResult(for: urlString, result: result)
        cacheTasks[urlString] = nil

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
