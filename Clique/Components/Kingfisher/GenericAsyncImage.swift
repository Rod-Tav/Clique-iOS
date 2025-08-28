//
//  ProgressiveAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/13/25.
//

import SwiftUI
import Kingfisher

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
    
    @State private var isMediumCached = false
    @State private var isHighCached = false
    
    var body: some View {
        ZStack {
            placeholder
                .opacity(!(isLowLoaded || isMediumLoaded || isHighLoaded) ? 1 : 0)
            
            // Always create KFImage views - let Kingfisher handle the complexity
            if quality == .low {
                content(KFImage(urlFor(urls?.lowQualityUrl))
                    .kfModifiers(shouldFade: true, loadingBug: loadingBug)
                    .onSuccess { _ in isLowLoaded = true }
                    .onFailure { _ in isLowLoaded = true }
                )
                .opacity(isLowLoaded && !isMediumCached && !isHighCached ? 1 : 0)
            }
            
            if quality == .medium || isMediumCached {
                content(KFImage(urlFor(urls?.medQualityUrl))
                    .kfModifiers(shouldFade: quality == .medium, loadingBug: loadingBug)
                    .onSuccess { _ in isMediumLoaded = true }
                    .onFailure { _ in isMediumLoaded = true }
                )
                .opacity(isMediumLoaded && !isHighCached ? 1 : 0)
            }
            
            if quality == .high || isHighCached {
                content(KFImage(urlFor(urls?.highQualityUrl))
                    .kfModifiers(shouldFade: quality == .high, loadingBug: loadingBug)
                    .onSuccess { _ in isHighLoaded = true }
                    .onFailure { _ in isHighLoaded = true }
                )
                .opacity(isHighLoaded ? 1 : 0)
            }
        }
        .fixedSize(horizontal: shouldFixSize, vertical: shouldFixSize)
        .task {
            // Simple cache check without blocking rendering
            if let highUrlString = urls?.highQualityUrl {
                isHighCached = await checkCache(for: highUrlString)
            }
            
            if let medUrlString = urls?.medQualityUrl {
                isMediumCached = await checkCache(for: medUrlString)
            }
        }
    }
    
    // Simple cache check that doesn't interfere with loading
    private func checkCache(for urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        // Use the base URL without query parameters for cache key
        let cacheKey = url.absoluteString.components(separatedBy: "?").first ?? url.absoluteString
        
        return await Task { @MainActor in
            KingfisherManager.shared.cache.isCached(forKey: cacheKey)
        }.value
    }
}
