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
                .opacity(!(isLowLoaded || isMediumLoaded || isHighLoaded) ? 0 : 0)
            
            if quality == .low {
                content(KFImage(urlFor(urls?.lowQualityUrl))
                    .kfModifiers(shouldFade: true)
                    .onSuccess { _ in isLowLoaded = true }
                    .onFailure { _ in isLowLoaded = true }
                )
                .opacity(isLowLoaded && !isMediumCached && !isHighCached ? 1 : 0)
            }
            
            if quality == .medium || isMediumCached {
                content(KFImage(urlFor(urls?.medQualityUrl))
                    .kfModifiers(shouldFade: quality == .medium)
                    .onSuccess { _ in isMediumLoaded = true }
                    .onFailure { _ in isMediumLoaded = true }
                )
                .opacity(isMediumLoaded && !isHighCached ? 1 : 0)
            }
            
            if quality == .high || isHighCached {
                content(KFImage(urlFor(urls?.highQualityUrl))
                    .kfModifiers(shouldFade: quality == .high)
                    .onSuccess { _ in isHighLoaded = true }
                    .onFailure { _ in isHighLoaded = true }
                )
                .opacity(isHighLoaded ? 1 : 0)
            }
        }
        .fixedSize(horizontal: shouldFixSize, vertical: shouldFixSize)
        .task {
            if let highUrlString = urls?.highQualityUrl, let highUrl = URL(string: highUrlString) {
                let isCached = KingfisherManager.shared.cache.isCached(forKey: highUrl.cacheKey)
                if isCached {
                    isHighCached = true
                }
            }
            
            if let medUrlString = urls?.medQualityUrl, let medUrl = URL(string: medUrlString) {
                let isCached = KingfisherManager.shared.cache.isCached(forKey: medUrl.cacheKey)
                if isCached {
                    isMediumCached = true
                }
            }
        }
    }
}
