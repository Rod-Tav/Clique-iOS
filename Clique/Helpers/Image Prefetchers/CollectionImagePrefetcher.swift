//
//  CollectionImagePrefetcher.swift
//  Clique
//
//  Created by Rod Tavangar on 3/5/25.
//

import Foundation
import Kingfisher
import UIKit

/// Instagram-level image prefetching system optimized for smooth scrolling
final class CollectionImagePrefetcher {
    static let instance = CollectionImagePrefetcher()

    // Prefetchers by collection ID
    private var lowPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    private var medPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    private var highPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]

    // Track prefetched URLs to support pagination
    private var prefetchedLowURLs: [String: Set<URL>] = [:]
    private var prefetchedMedURLs: [String: Set<URL>] = [:]
    private var prefetchedHighURLs: [String: Set<URL>] = [:]

    // Prefetching queue to avoid blocking main thread
    private let prefetchQueue = DispatchQueue(label: "com.clique.imagePrefetcher", qos: .utility)

    // Track active prefetch operations for smarter management
    private var activePrefetchCount = 0
    private let maxConcurrentPrefetches = 3

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

    // MARK: - Smart Prefetching Based on Context

    /// Prefetch images based on context (feed, detail view, etc.)
    func prefetchForContext(_ context: PrefetchContext, collectionId: String, images: [CollectionImage]) {
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }

            switch context {
            case .feedScroll:
                // For feed scrolling, prefetch only medium quality for visible items
                self.prefetchMediumQuality(collectionId: collectionId, images: Array(images.prefix(6)))

            case .detailView:
                // For detail view, prefetch high quality for current and adjacent images
                self.prefetchHighQuality(collectionId: collectionId, images: Array(images.prefix(5)))

            case .gridView:
                // For grid view, prefetch low quality for many items
                self.prefetchLowQuality(collectionId: collectionId, images: Array(images.prefix(20)))

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

        // If all new URLs are already being prefetched, skip
        if lowQualityUrls.allSatisfy({ previousLowURLs.contains($0) }) { return }

        // Stop existing and start new prefetcher
        lowPrefetchers[collectionId]?.stop()
        activePrefetchCount += 1
        lowPrefetchers[collectionId] = createSmartPrefetcher(
            with: Array(prefetchedLowURLs[collectionId]!.prefix(10)), // Limit to 10 for performance
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

        // If all new URLs are already being prefetched, skip
        if medUrls.allSatisfy({ previousMedURLs.contains($0) }) { return }

        medPrefetchers[collectionId]?.stop()
        activePrefetchCount += 1
        medPrefetchers[collectionId] = createSmartPrefetcher(
            with: Array(prefetchedMedURLs[collectionId]!.prefix(8)), // Limit to 8 for balance
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

        // If all new URLs are already being prefetched, skip
        if highUrls.allSatisfy({ previousHighURLs.contains($0) }) { return }

        highPrefetchers[collectionId]?.stop()
        activePrefetchCount += 1
        highPrefetchers[collectionId] = createSmartPrefetcher(
            with: Array(prefetchedHighURLs[collectionId]!.prefix(5)), // Limit to 5 for high quality
            quality: .high,
            collectionId: collectionId
        )
    }

    // MARK: - Stop Prefetching
    func stopPrefetching(collectionId: String) {
        prefetchQueue.async { [weak self] in
            self?.stopLowPrefetching(collectionId: collectionId)
            self?.stopMediumPrefetching(collectionId: collectionId)
            self?.stopHighPrefetching(collectionId: collectionId)
        }
    }

    private func stopAllPrefetching() {
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

    func stopLowPrefetching(collectionId: String) {
        lowPrefetchers[collectionId]?.stop()
        lowPrefetchers.removeValue(forKey: collectionId)
        prefetchedLowURLs.removeValue(forKey: collectionId)
        activePrefetchCount = max(0, activePrefetchCount - 1)
    }

    func stopMediumPrefetching(collectionId: String) {
        medPrefetchers[collectionId]?.stop()
        medPrefetchers.removeValue(forKey: collectionId)
        prefetchedMedURLs.removeValue(forKey: collectionId)
        activePrefetchCount = max(0, activePrefetchCount - 1)
    }

    func stopHighPrefetching(collectionId: String) {
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

        let options: KingfisherOptionsInfo = [
            .processor(DownsamplingImageProcessor(size: processorSize)),
            .scaleFactor(scale),
            .memoryCacheExpiration(.seconds(3600)),
            .diskCacheExpiration(.days(7)),
            .backgroundDecode,
            .cacheOriginalImage,
            .callbackQueue(.dispatch(prefetchQueue))
        ]

        let prefetcher = Kingfisher.ImagePrefetcher(
            urls: urls,
            options: options,
            completionHandler: { [weak self] skippedResources, failedResources, completedResources in
                DispatchQueue.main.async {
                    self?.activePrefetchCount = max(0, (self?.activePrefetchCount ?? 1) - 1)

                    #if DEBUG
                    if !failedResources.isEmpty {
                        print("⚠️ Prefetch failed for \(failedResources.count) images in collection \(collectionId)")
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