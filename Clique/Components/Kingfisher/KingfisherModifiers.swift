//
//  KingfisherModifiers.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import UIKit
import Kingfisher

extension KFImage {
    func kfModifiers(shouldFade: Bool = false) -> KFImage {
        self
            .cacheOriginalImage()
            .fade(duration: shouldFade ? 0.25 : 0)
            .onFailureImage(UIImage(named: "default-gradient"))
            .memoryCacheExpiration(.seconds(3600))
            .diskCacheExpiration(.days(7))
            .retry(maxCount: 3, interval: .accumulated(2))
    }
}

func urlFor(_ string: String?) -> URL? {
    guard let string, let url = URL(string: string) else { return nil }
    return url
}
