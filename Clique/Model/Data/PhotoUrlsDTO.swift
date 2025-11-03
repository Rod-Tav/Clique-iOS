//
//  PhotoUrlsDTO.swift (transitioning to MediaUrlsDTO)
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//  Updated by Claude on 1/31/25 for Live Photos and Videos support
//

import Foundation

func mapToMediaUrls(_ urls: Components.Schemas.MediaUrls) -> MediaUrls {
    return MediaUrls(
        url: urls.url,
        medQualityUrl: urls.medQualityUrl,
        lowQualityUrl: urls.lowQualityUrl
    )
}

/// Backward compatibility function - will be removed after full migration
func mapToPhotoUrls(_ urls: Components.Schemas.MediaUrls) -> MediaUrls {
    return mapToMediaUrls(urls)
}
