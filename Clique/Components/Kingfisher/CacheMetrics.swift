//
//  CacheMetrics.swift
//  Clique
//
//  Created by Claude on 9/27/25.
//

import Foundation

/// Tracks cache performance metrics for optimization and debugging
@MainActor
public final class CacheMetrics: ObservableObject {
    static let shared = CacheMetrics()

    // MARK: - Metrics
    @Published public private(set) var cacheHits: Int = 0
    @Published public private(set) var cacheMisses: Int = 0
    @Published public private(set) var totalRequests: Int = 0
    @Published public private(set) var hitRate: Double = 0.0

    // Network metrics
    @Published public private(set) var networkFetches: Int = 0
    @Published public private(set) var failedFetches: Int = 0
    @Published public private(set) var avgFetchTime: TimeInterval = 0.0

    // Performance metrics
    @Published public private(set) var prefetchedImages: Int = 0
    @Published public private(set) var prefetchHits: Int = 0
    @Published public private(set) var memoryWarnings: Int = 0

    // Session tracking
    private var sessionStartTime: Date
    private var fetchTimes: [TimeInterval] = []
    private let maxFetchTimeSamples = 100

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

        // Update average fetch time
        fetchTimes.append(duration)
        if fetchTimes.count > maxFetchTimeSamples {
            fetchTimes.removeFirst()
        }
        avgFetchTime = fetchTimes.reduce(0, +) / Double(max(1, fetchTimes.count))
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
        prefetchedImages = 0
        prefetchHits = 0
        memoryWarnings = 0
        fetchTimes.removeAll()
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