//
//  ProgressiveAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/13/25.
//

import SwiftUI
import Kingfisher

// Cache manager for GenericAsyncImage cache check results
enum GenericAsyncImageCache {
    static var cacheCheckResults: [String: (Bool, Date)] = [:]
    static let cacheResultTTL: TimeInterval = 2.0 // 2 seconds TTL
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
    
    var body: some View {
        ZStack {
            placeholder
                .opacity(!(isLowLoaded || isMediumLoaded || isHighLoaded) ? 1 : 0)
            
            // Only create KFImage views that we actually need
            if showLowQuality {
                content(KFImage(urlFor(urls?.lowQualityUrl))
                    .kfModifiers(shouldFade: false, loadingBug: loadingBug) // Never fade fallback quality
                    .onSuccess { _ in isLowLoaded = true }
                    .onFailure { _ in isLowLoaded = true }
                )
                .opacity((isLowLoaded || shouldShowCachedLow) && !isMediumLoaded && !isHighLoaded ? 1 : 0)
            }
            
            if showMediumQuality {
                content(KFImage(urlFor(urls?.medQualityUrl))
                    .kfModifiers(shouldFade: quality == .medium, loadingBug: loadingBug)
                    .onSuccess { _ in isMediumLoaded = true }
                    .onFailure { _ in isMediumLoaded = true }
                )
                .opacity((isMediumLoaded || shouldShowCachedMedium) && (!isHighLoaded || isHighFailed) ? 1 : 0)
            }
            
            if showHighQuality {
                content(KFImage(urlFor(urls?.highQualityUrl))
                    .kfModifiers(shouldFade: quality == .high, loadingBug: loadingBug)
                    .onSuccess { _ in isHighLoaded = true }
                    .onFailure { _ in isHighFailed = true }
                )
                .opacity(isHighLoaded ? 1 : 0)
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
    
    // Fast cache check using Kingfisher's proper cache key with result caching
    private func checkCache(for urlString: String) async -> Bool {
        // Check cached result first
        if let (cachedResult, timestamp) = GenericAsyncImageCache.cacheCheckResults[urlString],
           Date().timeIntervalSince(timestamp) < GenericAsyncImageCache.cacheResultTTL {
            return cachedResult
        }
        
        guard let url = URL(string: urlString) else { return false }
        
        let result = await Task { @MainActor in
            // Use Kingfisher's proper cache key generation
            let resource = KF.ImageResource(downloadURL: url)
            return KingfisherManager.shared.cache.isCached(forKey: resource.cacheKey)
        }.value
        
        // Cache the result
        GenericAsyncImageCache.cacheCheckResults[urlString] = (result, Date())
        
        return result
    }
}
