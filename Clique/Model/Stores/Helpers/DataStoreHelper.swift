//
//  DataStoreHelper.swift
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//

import Foundation

func shouldUpdatePhotoUrls(_ old: PhotoUrls?, _ new: PhotoUrls?, threshold: TimeInterval = 3600) -> Bool {
    guard let old = old, let new = new else {
        return old != new // If one is nil and the other isn't, we need to update
    }
    
    // Helper closure to check if a URL should be updated (if file changed or expired)
    func urlNeedsUpdate(_ oldUrl: String?, _ newUrl: String?) -> Bool {
        guard let oldUrl, let newUrl else { return oldUrl != newUrl } // One nil, one not? Update needed
        
        let oldBase = oldUrl.components(separatedBy: "?").first
        let newBase = newUrl.components(separatedBy: "?").first
        
        if oldBase != newBase {
            return true
        }
        
        // If base URLs are same, check if old URL has expired
        guard let oldDate = extractTimestamp(from: oldUrl) else {
            return true // If can't get timestamp, assume update needed
        }
        
        let expirationDate = oldDate.addingTimeInterval(threshold)
        let now = Date()
        
        if now > expirationDate {
            // expired
            return true
        }
        
        // Same file, not expired
        return false
    }
    
    // Check for update across all quality levels
    return urlNeedsUpdate(old.highQualityUrl, new.highQualityUrl) ||
    urlNeedsUpdate(old.medQualityUrl, new.medQualityUrl) ||
    urlNeedsUpdate(old.lowQualityUrl, new.lowQualityUrl)
}
