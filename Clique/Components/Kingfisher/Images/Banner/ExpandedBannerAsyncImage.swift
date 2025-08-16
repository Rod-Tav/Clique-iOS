//
//  CliqueBannerAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/2/25.
//

import SwiftUI
import Kingfisher

enum BannerType {
    case clique, collection
}

struct ExpandedBannerAsyncImage: View {
    let banner: PhotoUrls?
    let type: BannerType
    let quality: ImageQuality
    var showGradient: Bool = true
    
    var body: some View {
        if let banner {
            GenericAsyncImage(urls: banner, quality: quality) { image in
                image.contentConfigure { $0.expandedBannerModifiers(type: type, showGradient: showGradient) }
            } placeholder: {
                ExpandedBannerPlaceholder()
            }
        } else {
            Image("default-gradient")
                .expandedBannerModifiers(type: type, showGradient: showGradient)
        }
    }
}

struct ExpandedBannerPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.theme.iconTertiary)
            .frame(width: UIScreen.width, height: UIScreen.width / Constants.expandedBannerRatio)
    }
}

