//
//  PhotoUrls.swift
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//

import Foundation

struct PhotoUrls: Codable, Hashable, Sendable {
    var highQualityUrl: String? // High quality
    var medQualityUrl: String?  // Medium quality
    var lowQualityUrl: String?  // Low quality
    
    /// Initialize with URLs for each quality level.
    init(highQualityUrl: String? = nil, medQualityUrl: String? = nil, lowQualityUrl: String? = nil) {
        self.highQualityUrl = highQualityUrl
        self.medQualityUrl = medQualityUrl
        self.lowQualityUrl = lowQualityUrl
    }
    
    /// All quality levels in fallback order (high → low)
    var urls: [String?] {
        [highQualityUrl, medQualityUrl, lowQualityUrl]
    }
    
    /// All valid, non-nil URLs in fallback order
    var validUrls: [URL] {
        urls
            .compactMap { $0 }
            .compactMap(URL.init)
    }
}
