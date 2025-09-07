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
    @State private var isHighFailed = false
    
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
                .opacity(isLowLoaded && !isMediumLoaded && !isHighLoaded ? 1 : 0)
            }
            
            if quality == .medium || isMediumCached {
                content(KFImage(urlFor(urls?.medQualityUrl))
                    .kfModifiers(shouldFade: quality == .medium, loadingBug: loadingBug)
                    .onSuccess { _ in 
                        print("[GenericAsyncImage] Medium quality loaded successfully")
                        isMediumLoaded = true 
                    }
                    .onFailure { error in 
                        print("[GenericAsyncImage] Medium quality failed to load: \(error)")
                        isMediumLoaded = true 
                    }
                )
                .opacity(isMediumLoaded && (!isHighLoaded || isHighFailed) ? 1 : 0)
            }
            
            if quality == .high || isHighCached {
                content(KFImage(urlFor(urls?.highQualityUrl))
                    .kfModifiers(shouldFade: quality == .high, loadingBug: loadingBug)
                    .onSuccess { _ in 
                        print("[GenericAsyncImage] High quality loaded successfully")
                        isHighLoaded = true 
                    }
                    .onFailure { error in 
                        print("[GenericAsyncImage] High quality failed to load: \(error)")
                        isHighFailed = true
                    }
                )
                .opacity(isHighLoaded ? 1 : 0)
            }
        }
        .fixedSize(horizontal: shouldFixSize, vertical: shouldFixSize)
        .task {
            // Check cache status for all quality levels
            if let highUrlString = urls?.highQualityUrl {
                isHighCached = await checkCache(for: highUrlString)
                print("[GenericAsyncImage] High quality URL: \(highUrlString)")
                print("[GenericAsyncImage] High quality cached: \(isHighCached)")
            }
            
            if let medUrlString = urls?.medQualityUrl {
                isMediumCached = await checkCache(for: medUrlString)
                print("[GenericAsyncImage] Medium quality URL: \(medUrlString)")
                print("[GenericAsyncImage] Medium quality cached: \(isMediumCached)")
            }
            
            // For profile pictures in fullscreen: if medium is cached but we're requesting high quality,
            // immediately show medium while high quality loads
            if quality == .high && isMediumCached && !isHighCached {
                print("[GenericAsyncImage] Profile Picture Optimization: Showing cached medium quality immediately")
                isMediumLoaded = true
            }
            
            // Also check for low quality as fallback if neither medium nor high is cached
            if quality == .high && !isMediumCached && !isHighCached {
                if let lowUrlString = urls?.lowQualityUrl {
                    let isLowCached = await checkCache(for: lowUrlString)
                    if isLowCached {
                        print("[GenericAsyncImage] Profile Picture Fallback: Showing cached low quality immediately")
                        isLowLoaded = true
                    }
                }
            }
            
            print("[GenericAsyncImage] Quality: \(quality), Medium cached: \(isMediumCached), High cached: \(isHighCached)")
        }
    }
    
    // Check cache using Kingfisher's actual cache key logic
    private func checkCache(for urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { 
            print("[GenericAsyncImage] Invalid URL: \(urlString)")
            return false 
        }
        
        let result = await Task { @MainActor in
            // Use the full URL as Kingfisher does by default
            let cached = KingfisherManager.shared.cache.isCached(forKey: url.absoluteString)
            print("[GenericAsyncImage] Cache check for \(url.absoluteString.prefix(50))...: \(cached)")
            
            // Also check memory cache explicitly for better reliability
            let memoryCached = KingfisherManager.shared.cache.imageCachedType(forKey: url.absoluteString).cached
            print("[GenericAsyncImage] Memory cache check for \(url.absoluteString.prefix(50))...: \(memoryCached)")
            
            return cached || memoryCached
        }.value
        
        return result
    }
}
