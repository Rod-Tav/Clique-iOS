//
//  ProgressiveAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/13/25.
//

import SwiftUI
import Kingfisher

// Thread-safe cache manager for GenericAsyncImage cache check results
@MainActor
enum GenericAsyncImageCache {
    private static var cacheCheckResults: [String: (Bool, Date)] = [:]
    private static let cacheResultTTL: TimeInterval = 2.0 // 2 seconds TTL
    private static let maxCacheSize = 100 // Prevent unbounded growth
    
    static func getCachedResult(for url: String) -> Bool? {
        cleanupExpiredEntries()
        
        if let (cachedResult, timestamp) = cacheCheckResults[url],
           Date().timeIntervalSince(timestamp) < cacheResultTTL {
            return cachedResult
        }
        return nil
    }
    
    static func setCachedResult(for url: String, result: Bool) {
        // Prevent unbounded growth
        if cacheCheckResults.count >= maxCacheSize {
            // Remove oldest entries (simple cleanup - could be improved with LRU)
            let now = Date()
            cacheCheckResults = cacheCheckResults.filter { 
                now.timeIntervalSince($0.value.1) < cacheResultTTL 
            }
        }
        
        cacheCheckResults[url] = (result, Date())
    }
    
    private static func cleanupExpiredEntries() {
        let now = Date()
        cacheCheckResults = cacheCheckResults.filter { 
            now.timeIntervalSince($0.value.1) < cacheResultTTL 
        }
    }
}

struct GenericAsyncImage<Content: View, Placeholder: View>: View {
    let urls: PhotoUrls?
    var quality: ImageQuality
    var shouldFixSize: Bool = true
    var loadingBug: Bool = false
    
    let content: (KFImage) -> Content
    @ViewBuilder var placeholder: Placeholder
    
    @State private var isLowLoaded = false
    @State private var isMediumLoaded = false
    @State private var isHighLoaded = false
    @State private var isHighFailed = false
    
    @State private var showLowQuality = false
    @State private var showMediumQuality = false  
    @State private var showHighQuality = false
    
    @State private var shouldShowCachedLow = false
    @State private var shouldShowCachedMedium = false
    
    // MARK: - Computed Properties for Clean State Logic
    
    private var shouldShowPlaceholder: Bool {
        !(isLowLoaded || isMediumLoaded || isHighLoaded)
    }
    
    private var shouldShowLowQuality: Bool {
        (isLowLoaded || shouldShowCachedLow) && !isMediumLoaded && !isHighLoaded
    }
    
    private var shouldShowMediumQuality: Bool {
        (isMediumLoaded || shouldShowCachedMedium) && (!isHighLoaded || isHighFailed)
    }
    
    private var shouldShowHighQuality: Bool {
        isHighLoaded
    }
    
    var body: some View {
        ZStack {
            placeholder
                .opacity(shouldShowPlaceholder ? 1 : 0)
            
            // Only create KFImage views that we actually need
            if showLowQuality {
                content(KFImage(urlFor(urls?.lowQualityUrl))
                    .kfModifiers(shouldFade: false, loadingBug: loadingBug) // Never fade fallback quality
                    .onSuccess { _ in isLowLoaded = true }
                    .onFailure { _ in isLowLoaded = true }
                )
                .opacity(shouldShowLowQuality ? 1 : 0)
            }
            
            if showMediumQuality {
                content(KFImage(urlFor(urls?.medQualityUrl))
                    .kfModifiers(shouldFade: quality == .medium, loadingBug: loadingBug)
                    .onSuccess { _ in isMediumLoaded = true }
                    .onFailure { _ in isMediumLoaded = true }
                )
                .opacity(shouldShowMediumQuality ? 1 : 0)
            }
            
            if showHighQuality {
                content(KFImage(urlFor(urls?.highQualityUrl))
                    .kfModifiers(shouldFade: quality == .high, loadingBug: loadingBug)
                    .onSuccess { _ in isHighLoaded = true }
                    .onFailure { _ in isHighFailed = true }
                )
                .opacity(shouldShowHighQuality ? 1 : 0)
            }
        }
        .fixedSize(horizontal: shouldFixSize, vertical: shouldFixSize)
        .task {
            await determineQualityLevelsToShow()
        }
    }
    
    // Efficiently determine which quality levels to show based on cache status
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
        
        // Determine what to show based on requested quality and cache status
        switch quality {
        case .low:
            showLowQuality = true
            
        case .medium:
            showMediumQuality = true
            // Show low quality fallback if medium not cached
            if !isMediumCached && isLowCached {
                showLowQuality = true
                shouldShowCachedLow = true // Show cached immediately, but let onSuccess set isLoaded
            }
            
        case .high:
            showHighQuality = true
            // Progressive fallbacks
            if !isHighCached {
                if isMediumCached {
                    showMediumQuality = true
                    shouldShowCachedMedium = true // Show cached immediately
                } else if isLowCached {
                    showLowQuality = true
                    shouldShowCachedLow = true // Show cached immediately
                }
            }
        }
        
        print("[GenericAsyncImage] Quality: \(quality), Showing - Low: \(showLowQuality), Medium: \(showMediumQuality), High: \(showHighQuality)")
    }
    
    // Fast cache check using Kingfisher's proper cache key with thread-safe result caching
    private func checkCache(for urlString: String) async -> Bool {
        // Check cached result first
        if let cachedResult = GenericAsyncImageCache.getCachedResult(for: urlString) {
            return cachedResult
        }
        
        guard let url = URL(string: urlString) else { return false }
        
        let result = await Task { @MainActor in
            // Use Kingfisher's proper cache key generation
            let resource = KF.ImageResource(downloadURL: url)
            return KingfisherManager.shared.cache.isCached(forKey: resource.cacheKey)
        }.value
        
        // Cache the result using thread-safe manager
        GenericAsyncImageCache.setCachedResult(for: urlString, result: result)
        
        return result
    }
}
