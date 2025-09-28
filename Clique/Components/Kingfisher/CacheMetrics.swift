//
//  CacheMetrics.swift
//  Clique
//
//  Created by Claude on 9/27/25.
//

import Foundation

/// Tracks cache performance metrics for optimization and debugging
/// Thread-safe implementation using actor isolation for concurrent access
public actor CacheMetrics {
    static let shared = CacheMetrics()

    // MARK: - Metrics
    public private(set) var cacheHits: Int = 0
    public private(set) var cacheMisses: Int = 0
    public private(set) var totalRequests: Int = 0
    public private(set) var hitRate: Double = 0.0

    // Network metrics
    public private(set) var networkFetches: Int = 0
    public private(set) var failedFetches: Int = 0
    public private(set) var avgFetchTime: TimeInterval = 0.0

    // Latency percentiles
    public private(set) var p50FetchTime: TimeInterval = 0.0
    public private(set) var p90FetchTime: TimeInterval = 0.0
    public private(set) var p99FetchTime: TimeInterval = 0.0

    // Performance metrics
    public private(set) var prefetchedImages: Int = 0
    public private(set) var prefetchHits: Int = 0
    public private(set) var memoryWarnings: Int = 0

    // Enhanced metrics
    public private(set) var cacheEvictions: Int = 0
    public private(set) var totalImageBytes: Int64 = 0
    public private(set) var avgImageSize: Int64 = 0
    public private(set) var ttfbSum: TimeInterval = 0.0 // Time to first byte
    public private(set) var ttfbCount: Int = 0
    public private(set) var avgTTFB: TimeInterval = 0.0

    // View-specific hit rates (bounded to prevent memory growth)
    private var viewHitRates: [String: (hits: Int, misses: Int)] = [:]
    public private(set) var viewMetrics: [String: Double] = [:]
    private let maxViewContexts = 50 // Limit number of tracked view contexts
    private var viewContextAccessOrder: [String] = [] // LRU tracking

    // Session tracking
    private var sessionStartTime: Date

    // Circular buffer for efficient fetch time tracking
    private var fetchTimes: [TimeInterval] = []
    private var fetchTimeIndex: Int = 0
    private let maxFetchTimeSamples = 100
    private var fetchTimesCount: Int = 0

    private init() {
        sessionStartTime = Date()
    }

    // MARK: - Recording Methods

    /// Record a cache hit
    func recordCacheHit(viewContext: String? = nil) {
        cacheHits += 1
        totalRequests += 1
        updateHitRate()

        // Track view-specific metrics
        if let context = viewContext {
            enforceViewContextLimit(context)
            let current = viewHitRates[context] ?? (0, 0)
            viewHitRates[context] = (current.hits + 1, current.misses)
            updateViewMetrics(for: context)
        }
    }

    /// Record a cache miss
    func recordCacheMiss(viewContext: String? = nil) {
        cacheMisses += 1
        totalRequests += 1
        updateHitRate()

        // Track view-specific metrics
        if let context = viewContext {
            enforceViewContextLimit(context)
            let current = viewHitRates[context] ?? (0, 0)
            viewHitRates[context] = (current.hits, current.misses + 1)
            updateViewMetrics(for: context)
        }
    }

    /// Record a network fetch
    func recordNetworkFetch(duration: TimeInterval, success: Bool) {
        networkFetches += 1
        if !success {
            failedFetches += 1
        }

        // Validate duration to prevent negative values from skewing metrics
        let validDuration = max(0, duration)

        // Update fetch time metrics using circular buffer
        if fetchTimes.count < maxFetchTimeSamples {
            fetchTimes.append(validDuration)
            fetchTimesCount += 1
        } else {
            // Circular buffer: overwrite oldest value
            fetchTimes[fetchTimeIndex] = validDuration
            fetchTimeIndex = (fetchTimeIndex + 1) % maxFetchTimeSamples
            if fetchTimesCount < maxFetchTimeSamples {
                fetchTimesCount = maxFetchTimeSamples
            }
        }

        // Calculate average
        avgFetchTime = fetchTimes.reduce(0, +) / Double(max(1, fetchTimes.count))

        // Calculate percentiles
        updatePercentiles()
    }

    /// Record prefetch activity
    func recordPrefetch(count: Int) {
        prefetchedImages += count
    }

    /// Record when prefetched image is used
    func recordPrefetchHit() {
        prefetchHits += 1
    }

    /// Record memory warning
    func recordMemoryWarning() {
        memoryWarnings += 1
    }

    /// Record cache eviction
    func recordCacheEviction(count: Int = 1) {
        cacheEvictions += count
    }

    /// Record image size
    func recordImageSize(bytes: Int64) {
        totalImageBytes += bytes
        let imageCount = cacheHits + networkFetches
        if imageCount > 0 {
            avgImageSize = totalImageBytes / Int64(imageCount)
        }
    }

    /// Record time to first byte
    func recordTTFB(duration: TimeInterval) {
        ttfbSum += duration
        ttfbCount += 1
        avgTTFB = ttfbSum / Double(max(1, ttfbCount))
    }

    private func enforceViewContextLimit(_ context: String) {
        // Remove from current position if exists
        viewContextAccessOrder.removeAll { $0 == context }
        // Add to end (most recently used)
        viewContextAccessOrder.append(context)

        // Evict least recently used contexts if over limit
        while viewContextAccessOrder.count > maxViewContexts {
            let evictedContext = viewContextAccessOrder.removeFirst()
            viewHitRates.removeValue(forKey: evictedContext)
            viewMetrics.removeValue(forKey: evictedContext)
        }
    }

    private func updateViewMetrics(for context: String) {
        guard let stats = viewHitRates[context] else { return }
        let total = stats.hits + stats.misses
        if total > 0 {
            viewMetrics[context] = Double(stats.hits) / Double(total)
        }
    }

    // MARK: - Computed Metrics

    private func updateHitRate() {
        hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0
    }

    private func updatePercentiles() {
        guard !fetchTimes.isEmpty else {
            p50FetchTime = 0
            p90FetchTime = 0
            p99FetchTime = 0
            return
        }

        // Get actual values from circular buffer
        let actualCount = min(fetchTimesCount, maxFetchTimeSamples)
        let sortedTimes = Array(fetchTimes.prefix(actualCount).sorted())

        // Handle edge cases for small sample sizes
        switch sortedTimes.count {
        case 1:
            // With 1 sample, all percentiles are the same
            p50FetchTime = sortedTimes[0]
            p90FetchTime = sortedTimes[0]
            p99FetchTime = sortedTimes[0]
        case 2:
            // With 2 samples, p50 is average, p90/p99 is max
            p50FetchTime = (sortedTimes[0] + sortedTimes[1]) / 2
            p90FetchTime = sortedTimes[1]
            p99FetchTime = sortedTimes[1]
        case 3...5:
            // With 3-5 samples, use simplified percentiles
            p50FetchTime = sortedTimes[sortedTimes.count / 2]
            p90FetchTime = sortedTimes[sortedTimes.count - 1] // Use max for p90
            p99FetchTime = sortedTimes[sortedTimes.count - 1] // Use max for p99
        case 6...10:
            // With 6-10 samples, differentiate p90 and p99
            let p50Index = sortedTimes.count / 2
            let p90Index = min(sortedTimes.count - 1, Int(Double(sortedTimes.count) * 0.9))
            p50FetchTime = sortedTimes[p50Index]
            p90FetchTime = sortedTimes[p90Index]
            p99FetchTime = sortedTimes[sortedTimes.count - 1] // Still use max for p99
        default:
            // With 11+ samples, use standard percentile calculation
            let count = sortedTimes.count
            let p50Index = Int(Double(count - 1) * 0.5)
            let p90Index = Int(Double(count - 1) * 0.9)
            let p99Index = Int(Double(count - 1) * 0.99)

            p50FetchTime = sortedTimes[p50Index]
            p90FetchTime = sortedTimes[p90Index]
            p99FetchTime = sortedTimes[p99Index]
        }
    }

    /// Get session duration
    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    /// Get network success rate
    var networkSuccessRate: Double {
        networkFetches > 0 ? Double(networkFetches - failedFetches) / Double(networkFetches) : 1.0
    }

    /// Get prefetch effectiveness
    var prefetchEffectiveness: Double {
        prefetchedImages > 0 ? Double(prefetchHits) / Double(prefetchedImages) : 0.0
    }

    // MARK: - Reporting

    /// Generate metrics report
    func generateReport() -> String {
        """
        📊 Cache Metrics Report
        ========================
        Session Duration: \(String(format: "%.1f", sessionDuration))s

        Cache Performance:
        - Hit Rate: \(String(format: "%.1f%%", hitRate * 100))
        - Total Requests: \(totalRequests)
        - Hits: \(cacheHits) | Misses: \(cacheMisses)
        - Evictions: \(cacheEvictions)

        Network:
        - Fetches: \(networkFetches)
        - Success Rate: \(String(format: "%.1f%%", networkSuccessRate * 100))
        - Avg Fetch Time: \(String(format: "%.2fs", avgFetchTime))
        - Avg TTFB: \(String(format: "%.2fs", avgTTFB))
        - P50 Latency: \(String(format: "%.2fs", p50FetchTime))
        - P90 Latency: \(String(format: "%.2fs", p90FetchTime))
        - P99 Latency: \(String(format: "%.2fs", p99FetchTime))

        Prefetching:
        - Images Prefetched: \(prefetchedImages)
        - Effectiveness: \(String(format: "%.1f%%", prefetchEffectiveness * 100))

        System:
        - Memory Warnings: \(memoryWarnings)
        - Avg Image Size: \(String(format: "%.1f KB", Double(avgImageSize) / 1024))

        View-Specific Hit Rates:
        \(viewMetrics.map { "- \($0.key): \(String(format: "%.1f%%", $0.value * 100))" }.joined(separator: "\n"))
        """
    }

    /// Reset all metrics
    func reset() {
        cacheHits = 0
        cacheMisses = 0
        totalRequests = 0
        hitRate = 0.0
        networkFetches = 0
        failedFetches = 0
        avgFetchTime = 0.0
        p50FetchTime = 0.0
        p90FetchTime = 0.0
        p99FetchTime = 0.0
        prefetchedImages = 0
        prefetchHits = 0
        memoryWarnings = 0
        cacheEvictions = 0
        totalImageBytes = 0
        avgImageSize = 0
        ttfbSum = 0.0
        ttfbCount = 0
        avgTTFB = 0.0
        viewHitRates.removeAll()
        viewMetrics.removeAll()
        viewContextAccessOrder.removeAll()
        fetchTimes.removeAll()
        fetchTimeIndex = 0
        fetchTimesCount = 0
        sessionStartTime = Date()
    }

    // MARK: - Debug Logging

    #if DEBUG
    /// Print metrics to console
    func logMetrics() {
        print(generateReport())
    }
    #endif
}