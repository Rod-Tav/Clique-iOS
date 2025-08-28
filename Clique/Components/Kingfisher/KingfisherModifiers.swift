//
//  KingfisherModifiers.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import UIKit
import Kingfisher

extension KFImage {
    func kfModifiers(shouldFade: Bool = false, loadingBug: Bool = false) -> KFImage {
        self
            .startLoadingBeforeViewAppear(loadingBug)
            .cacheOriginalImage()
            .fade(duration: shouldFade ? 0.15 : 0) // Reduced from 0.25s
            .onFailureImage(UIImage(named: "default-gradient"))
            .memoryCacheExpiration(.seconds(3600))
            .diskCacheExpiration(.days(7))
            .retry(maxCount: 1, interval: .seconds(0.5)) // Reduced from 3 retries with 2s interval
    }
}

func urlFor(_ string: String?) -> URL? {
    guard let string, let url = URL(string: string) else { return nil }
    return url
}
