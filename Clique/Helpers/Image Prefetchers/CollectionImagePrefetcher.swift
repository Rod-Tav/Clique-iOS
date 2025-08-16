//
//  CollectionImagePrefetcher.swift
//  Clique
//
//  Created by Rod Tavangar on 3/5/25.
//

import Foundation
import Kingfisher

final class CollectionImagePrefetcher {
    static let instance = CollectionImagePrefetcher()
    
    // Prefetchers by collection ID
    private var lowPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    private var medPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    private var highPrefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
    
    // Track prefetched URLs to support pagination (avoiding re-fetching same images)
    private var prefetchedLowURLs: [String: Set<URL>] = [:]
    private var prefetchedMedURLs: [String: Set<URL>] = [:]
    private var prefetchedHighURLs: [String: Set<URL>] = [:]
    
    private init() {}
    
    // MARK: - Low Quality Prefetching
    func prefetchLowQuality(collectionId: String, images: [CollectionImage]) {
        let lowQualityUrls = images
            .compactMap { URL(string: $0.imageUrl?.lowQualityUrl ?? "") }
            .filter { !ImageCache.default.isCached(forKey: $0.absoluteString) }
        
        guard !lowQualityUrls.isEmpty else { return }
        
        let previousLowURLs = prefetchedLowURLs[collectionId] ?? []
        prefetchedLowURLs[collectionId, default: []].formUnion(lowQualityUrls)
        
        // If already prefetching the same URLs, skip
        if previousLowURLs == prefetchedLowURLs[collectionId] { return }
        
        // Stop existing and start new prefetcher
        lowPrefetchers[collectionId]?.stop()
        lowPrefetchers[collectionId] = createPrefetcher(with: Array(prefetchedLowURLs[collectionId]!), quality: .low)
    }
    
    // MARK: - Medium Quality Prefetching
    func prefetchMediumQuality(collectionId: String, images: [CollectionImage]) {
        let medUrls = images
            .compactMap { URL(string: $0.imageUrl?.medQualityUrl ?? "") }
            .filter { !ImageCache.default.isCached(forKey: $0.absoluteString) }
        
        guard !medUrls.isEmpty else { return }
        
        let previousMedURLs = prefetchedMedURLs[collectionId] ?? []
        prefetchedMedURLs[collectionId, default: []].formUnion(medUrls)
        
        if previousMedURLs == prefetchedMedURLs[collectionId] { return }
        
        medPrefetchers[collectionId]?.stop()
        medPrefetchers[collectionId] = createPrefetcher(with: Array(prefetchedMedURLs[collectionId]!), quality: .medium)
    }
    
    // MARK: - High Quality Prefetching
    func prefetchHighQuality(collectionId: String, images: [CollectionImage]) {
        let highUrls = images
            .compactMap { URL(string: $0.imageUrl?.highQualityUrl ?? "") }
            .filter { !ImageCache.default.isCached(forKey: $0.absoluteString) }
        
        guard !highUrls.isEmpty else { return }
        
        let previousHighURLs = prefetchedHighURLs[collectionId] ?? []
        prefetchedHighURLs[collectionId, default: []].formUnion(highUrls)
        
        if previousHighURLs == prefetchedHighURLs[collectionId] { return }
        
        highPrefetchers[collectionId]?.stop()
        highPrefetchers[collectionId] = createPrefetcher(with: Array(prefetchedHighURLs[collectionId]!), quality: .high)
    }
    
    // MARK: - Stop All Prefetching for a Collection
    func stopPrefetching(collectionId: String) {
        stopLowPrefetching(collectionId: collectionId)
        stopMediumPrefetching(collectionId: collectionId)
        stopHighPrefetching(collectionId: collectionId)
    }
    
    // MARK: - Stop Only Low Quality
    func stopLowPrefetching(collectionId: String) {
        lowPrefetchers[collectionId]?.stop()
        lowPrefetchers.removeValue(forKey: collectionId)
        prefetchedLowURLs.removeValue(forKey: collectionId)
    }
    
    // MARK: - Stop Only Medium Quality
    func stopMediumPrefetching(collectionId: String) {
        medPrefetchers[collectionId]?.stop()
        medPrefetchers.removeValue(forKey: collectionId)
        prefetchedMedURLs.removeValue(forKey: collectionId)
    }
    
    // MARK: - Stop Only High Quality
    func stopHighPrefetching(collectionId: String) {
        highPrefetchers[collectionId]?.stop()
        highPrefetchers.removeValue(forKey: collectionId)
        prefetchedHighURLs.removeValue(forKey: collectionId)
    }
    
    // MARK: - Private Helper
    private func createPrefetcher(with urls: [URL], quality: Quality) -> Kingfisher.ImagePrefetcher {
        let options: KingfisherOptionsInfo = [
            .cacheMemoryOnly,
            .memoryCacheExpiration(.seconds(600)) // 10 minutes
        ]
        
        let prefetcher = Kingfisher.ImagePrefetcher(urls: urls, options: options)
        prefetcher.start() // Start immediately for all quality levels
        return prefetcher
    }
    
    // MARK: - Quality Enum
    private enum Quality {
        case low, medium, high
    }
}
