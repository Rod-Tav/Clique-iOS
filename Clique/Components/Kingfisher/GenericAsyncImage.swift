//
//  ProgressiveAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/13/25.
//

import SwiftUI
import Kingfisher

// Instance-based cache manager for GenericAsyncImage cache check results
@MainActor
final class GenericAsyncImageCacheManager: ObservableObject {
    static let shared = GenericAsyncImageCacheManager()
    
    private var cacheCheckResults: [String: (Bool, Date)] = [:]
    private let cacheResultTTL: TimeInterval = 2.0 // 2 seconds TTL
    private let maxCacheSize = 100 // Prevent unbounded growth
    private var lastCleanupTime: Date = Date()
    private let cleanupInterval: TimeInterval = 30.0 // Cleanup every 30 seconds
    
    private init() {
        setupCleanupTimer()
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
        // Background cleanup timer
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
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
    }
}

struct GenericAsyncImage<Content: View, Placeholder: View>: View {
    let urls: PhotoUrls?
    var quality: ImageQuality
    var shouldFixSize: Bool = true
    var loadingBug: Bool = false
    
    let content: (KFImage) -> Content
    @ViewBuilder var placeholder: Placeholder
    
    // MARK: - State Machine
    
    enum LoadingState {
        case notStarted
        case loading
        case loaded
        case failed
    }
    
    @State private var lowQualityState: LoadingState = .notStarted
    @State private var mediumQualityState: LoadingState = .notStarted
    @State private var highQualityState: LoadingState = .notStarted
    
    @State private var showLowQuality = false
    @State private var showMediumQuality = false  
    @State private var showHighQuality = false
    
    @State private var hasCachedLow = false
    @State private var hasCachedMedium = false
    
    private let cacheManager = GenericAsyncImageCacheManager.shared
    
    // MARK: - Computed Properties for Clean State Logic
    
    private var shouldShowPlaceholder: Bool {
        lowQualityState != .loaded && mediumQualityState != .loaded && highQualityState != .loaded &&
        !hasCachedLow && !hasCachedMedium
    }
    
    private var shouldShowLowQuality: Bool {
        (lowQualityState == .loaded || hasCachedLow) && 
        mediumQualityState != .loaded && 
        highQualityState != .loaded
    }
    
    private var shouldShowMediumQuality: Bool {
        (mediumQualityState == .loaded || hasCachedMedium) && 
        (highQualityState != .loaded || highQualityState == .failed)
    }
    
    private var shouldShowHighQuality: Bool {
        highQualityState == .loaded
    }
    
    var body: some View {
        ZStack {
            placeholder
                .opacity(shouldShowPlaceholder ? 1 : 0)
            
            // Only create KFImage views that we actually need
            if showLowQuality {
                qualityImageView(
                    url: urls?.lowQualityUrl,
                    shouldFade: false, // Never fade fallback quality
                    onSuccess: { lowQualityState = .loaded },
                    onFailure: { lowQualityState = .failed }
                )
                .opacity(shouldShowLowQuality ? 1 : 0)
            }
            
            if showMediumQuality {
                qualityImageView(
                    url: urls?.medQualityUrl,
                    shouldFade: quality == .medium,
                    onSuccess: { mediumQualityState = .loaded },
                    onFailure: { mediumQualityState = .failed }
                )
                .opacity(shouldShowMediumQuality ? 1 : 0)
            }
            
            if showHighQuality {
                qualityImageView(
                    url: urls?.highQualityUrl,
                    shouldFade: quality == .high,
                    onSuccess: { highQualityState = .loaded },
                    onFailure: { highQualityState = .failed }
                )
                .opacity(shouldShowHighQuality ? 1 : 0)
            }
        }
        .fixedSize(horizontal: shouldFixSize, vertical: shouldFixSize)
        .task {
            await determineQualityLevelsToShow()
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
        content(KFImage(urlFor(url))
            .kfModifiers(shouldFade: shouldFade, loadingBug: loadingBug)
            .onSuccess { _ in onSuccess() }
            .onFailure { _ in onFailure() }
        )
    }
    
    @MainActor
    private func determineQualityLevelsToShow() async {
        // Batch cache checks to minimize async overhead
        let cacheResults = await withTaskGroup(of: (String, Bool).self) { group in
            var results: [String: Bool] = [:]
            
            if let highUrl = urls?.highQualityUrl {
                group.addTask { ("high", await self.checkCache(for: highUrl)) }
            }
            if let medUrl = urls?.medQualityUrl {
                group.addTask { ("medium", await self.checkCache(for: medUrl)) }
            }
            if let lowUrl = urls?.lowQualityUrl {
                group.addTask { ("low", await self.checkCache(for: lowUrl)) }
            }
            
            for await (qualityKey, isCached) in group {
                results[qualityKey] = isCached
            }
            
            return results
        }
        
        let isHighCached = cacheResults["high"] ?? false
        let isMediumCached = cacheResults["medium"] ?? false
        let isLowCached = cacheResults["low"] ?? false
        
        // Set cached flags for immediate display
        hasCachedLow = isLowCached
        hasCachedMedium = isMediumCached
        
        // Determine what to show based on requested quality and cache status
        switch quality {
        case .low:
            showLowQuality = true
            
        case .medium:
            showMediumQuality = true
            // Show low quality fallback if medium not cached
            if !isMediumCached && isLowCached {
                showLowQuality = true
            }
            
        case .high:
            showHighQuality = true
            // Progressive fallbacks
            if !isHighCached {
                if isMediumCached {
                    showMediumQuality = true
                } else if isLowCached {
                    showLowQuality = true
                }
            }
        }
        
        print("[GenericAsyncImage] Quality: \(quality), Showing - Low: \(showLowQuality), Medium: \(showMediumQuality), High: \(showHighQuality)")
    }
    
    private func checkCache(for urlString: String) async -> Bool {
        // Check cached result first
        if let cachedResult = cacheManager.getCachedResult(for: urlString) {
            return cachedResult
        }
        
        guard let url = URL(string: urlString) else { return false }
        
        let result = await Task { @MainActor in
            // Use Kingfisher's proper cache key generation
            let resource = KF.ImageResource(downloadURL: url)
            return KingfisherManager.shared.cache.isCached(forKey: resource.cacheKey)
        }.value
        
        // Cache the result using instance-based manager
        cacheManager.setCachedResult(for: urlString, result: result)
        
        return result
    }
}
