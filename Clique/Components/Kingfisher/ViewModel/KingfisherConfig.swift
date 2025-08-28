//
//  KingfisherConfig.swift
//  Clique
//
//  Created by Rod Tavangar on 3/14/25.
//

import Foundation
import Kingfisher
import UIKit

struct KingfisherConfig {
    static func configure() {
        let cache = ImageCache.default
        
        // Detect device capabilities for optimal configuration
        let isProDevice = UIDevice.current.userInterfaceIdiom == .phone && 
                         ProcessInfo.processInfo.physicalMemory > 6_000_000_000 // 6GB+ RAM
        
        // Memory cache configuration - increase for Pro devices
        cache.memoryStorage.config.totalCostLimit = isProDevice ? 
            400 * 1024 * 1024 :  // 400 MB for Pro devices
            200 * 1024 * 1024    // 200 MB for standard devices
        cache.memoryStorage.config.expiration = .seconds(3600) // 1 hour
        cache.memoryStorage.config.countLimit = isProDevice ? 800 : 500
        
        // Disk cache configuration - increase for better persistence
        cache.diskStorage.config.sizeLimit = 1024 * 1024 * 1024 // 1 GB max on disk
        cache.diskStorage.config.expiration = .days(7) // Cache expires after 7 days
        
        // Configure default image processor for downsampling
        configureImageProcessor()
        
        // Configure default options for better performance
        KingfisherManager.shared.defaultOptions = [
            .processor(DownsamplingImageProcessor(size: UIScreen.main.bounds.size)),
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage,
            .backgroundDecode, // Decode images in background to prevent main thread blocking
            .preloadAllAnimationData // For GIFs if any
        ]
        
        print("✅ Kingfisher cache configured: Pro-optimized settings, downsampling enabled.")
    }
    
    private static func configureImageProcessor() {
        // Create a default downsampling processor to reduce memory usage
        // This processor will be used globally unless overridden
        let screenSize = UIScreen.main.bounds.size
        let maxDimension = max(screenSize.width, screenSize.height) * UIScreen.main.scale
        
        // Set a reasonable max size for images (2x screen size for quality)
        let processor = DownsamplingImageProcessor(size: CGSize(width: maxDimension * 2, height: maxDimension * 2))
        
        // Apply as default processor
        KingfisherManager.shared.defaultOptions += [
            .processor(processor),
            .cacheSerializer(FormatIndicatedCacheSerializer.png) // Use PNG for better quality
        ]
    }
}
