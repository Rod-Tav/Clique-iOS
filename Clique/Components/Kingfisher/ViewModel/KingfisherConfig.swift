//
//  KingfisherConfig.swift
//  Clique
//
//  Created by Rod Tavangar on 3/14/25.
//

import Foundation
import Kingfisher

struct KingfisherConfig {
    static func configure() {
        let cache = ImageCache.default
        
        // Memory cache configuration
        cache.memoryStorage.config.totalCostLimit = 200 * 1024 * 1024 // 200 MB
        cache.memoryStorage.config.expiration = .seconds(3600) // 1 hour
        cache.memoryStorage.config.countLimit = 500
        
        // Disk cache configuration
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500 MB max on disk
        cache.diskStorage.config.expiration = .days(3) // Cache expires after 3 days
        
        print("✅ Kingfisher cache configured: memory + disk cache, capped and safe.")
    }
}
