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
    func recordCacheHit() {
        cacheHits += 1
        totalRequests += 1
        updateHitRate()
    }

    /// Record a cache miss
    func recordCacheMiss() {
        cacheMisses += 1
        totalRequests += 1
        updateHitRate()
    }

    /// Record a network fetch
    func recordNetworkFetch(duration: TimeInterval, success: Bool) {
        networkFetches += 1
        if !success {
            failedFetches += 1
        }

        // Update fetch time metrics using circular buffer
        if fetchTimes.count < maxFetchTimeSamples {
            fetchTimes.append(duration)
            fetchTimesCount += 1
        } else {
            // Circular buffer: overwrite oldest value
            fetchTimes[fetchTimeIndex] = duration
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
        let actualTimes = fetchTimesCount < maxFetchTimeSamples ? fetchTimes : fetchTimes
        let sortedTimes = actualTimes.sorted()
        let count = min(fetchTimesCount, actualTimes.count)

        // Calculate percentile indices (corrected for small sample sizes)
        let p50Index = max(0, Int(Double(count - 1) * 0.5))
        let p90Index = max(0, Int(Double(count - 1) * 0.9))
        let p99Index = max(0, Int(Double(count - 1) * 0.99))

        // Get percentile values (indices are guaranteed to be within bounds)
        p50FetchTime = sortedTimes[p50Index]
        p90FetchTime = sortedTimes[p90Index]
        p99FetchTime = sortedTimes[p99Index]
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

        Network:
        - Fetches: \(networkFetches)
        - Success Rate: \(String(format: "%.1f%%", networkSuccessRate * 100))
        - Avg Fetch Time: \(String(format: "%.2fs", avgFetchTime))
        - P50 Latency: \(String(format: "%.2fs", p50FetchTime))
        - P90 Latency: \(String(format: "%.2fs", p90FetchTime))
        - P99 Latency: \(String(format: "%.2fs", p99FetchTime))

        Prefetching:
        - Images Prefetched: \(prefetchedImages)
        - Effectiveness: \(String(format: "%.1f%%", prefetchEffectiveness * 100))

        System:
        - Memory Warnings: \(memoryWarnings)
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