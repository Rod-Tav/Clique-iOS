//
//  PhotoUrlsDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//

import Foundation

func mapToPhotoUrls(_ urls: Components.Schemas.PhotoUrls) -> PhotoUrls {
    return PhotoUrls(highQualityUrl: urls.url, medQualityUrl: urls.medQualityUrl, lowQualityUrl: urls.lowQualityUrl)
}
