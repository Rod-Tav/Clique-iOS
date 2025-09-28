//
//  KingfisherModifiers.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import UIKit
import Kingfisher

extension KFImage {
    func kfModifiers(shouldFade: Bool = false, loadingBug: Bool = false, isPrefetch: Bool = false) -> KFImage {
        // Adjust retry strategy based on context
        // Prefetch: fail fast with fewer retries
        // Display: more retries for user-visible content
        let retryCount = isPrefetch ? 0 : 2
        let retryInterval: TimeInterval = isPrefetch ? 0.5 : 1.0

        return self
            .startLoadingBeforeViewAppear(loadingBug)
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
