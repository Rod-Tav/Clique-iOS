//
//  KingfisherModifiers.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import UIKit
import Kingfisher

/// Context for image loading to determine optimal loading strategy.
///
/// Different contexts require different loading behaviors:
/// - **List/Grid**: Need `startLoadingBeforeViewAppear` to work around iOS 16-18 List lifecycle bug
/// - **Detail/Hero**: Standard loading without workaround for better performance
enum ImageLoadingContext {
    case list          // Profile lists, clique member lists
    case grid          // Photo grids, collection grids
    case detail        // Detail views, full-screen images
    case hero          // Hero images with transitions

    /// Whether this context requires pre-loading before view appears.
    /// This works around the iOS 16-18 List lifecycle bug where onAppear doesn't fire reliably.
    var requiresPreloading: Bool {
        switch self {
        case .list, .grid:
            return true
        case .detail, .hero:
            return false
        }
    }
}

extension KFImage {
    func kfModifiers(shouldFade: Bool = false, context: ImageLoadingContext = .detail, isPrefetch: Bool = false) -> KFImage {
        // Adjust retry strategy based on context
        // Prefetch: fail fast with fewer retries
        // Display: more retries for user-visible content
        let retryCount = isPrefetch ? 0 : 2
        let retryInterval: TimeInterval = isPrefetch ? 0.5 : 1.0

        return self
            // MARK: - Commented out as smart retry system in GenericAsyncImage handles stuck placeholders
            // Network-adaptive timeout with forced preload catches and fixes gray placeholders:
            // - WiFi/Ethernet: 750ms timeout
            // - Cellular: 2000ms timeout
            // - Unknown: 1500ms timeout
            // Re-enable if gray placeholders return on specific iOS versions (known issue on iOS 16-18)
            // See: https://github.com/onevcat/Kingfisher/issues/1988
//            .startLoadingBeforeViewAppear(context.requiresPreloading)
            .cacheOriginalImage()
            .fade(duration: shouldFade ? 0.15 : 0) // Reduced from 0.25s
            .onFailureImage(UIImage(named: "default-gradient"))
            .memoryCacheExpiration(.seconds(3600))
            .diskCacheExpiration(.days(7))
            .retry(maxCount: retryCount, interval: .seconds(retryInterval)) // Adaptive retry based on context
            .downloadPriority(isPrefetch ? 0.3 : 0.8) // Lower priority for prefetch
    }
}

func urlFor(_ string: String?) -> URL? {
    guard let string, let url = URL(string: string) else { return nil }
    return url
}
