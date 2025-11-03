//
//  HeroImageAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/16/25.
//

import SwiftUI
import Kingfisher

import SwiftUI
import Kingfisher

struct HeroImageAsyncView: View {
    let urls: PhotoUrls
    let size: CGSize
    let animateView: Bool
    let onImageLoaded: (UIImage) -> Void

    var body: some View {
        // High quality
        KFImage(urlFor(urls.highQualityUrl))
            .kfModifiers()
            .onSuccess { result in
                onImageLoaded(result.image)
            }
            .resizable()
            .placeholder {
                // Medium quality
                KFImage(urlFor(urls.medQualityUrl))
                    .kfModifiers()
                    .resizable()
                    .placeholder {
                        // Low quality
                        KFImage(urlFor(urls.lowQualityUrl))
                            .kfModifiers()
                            .resizable()
                            .placeholder {
                                Color.clear
                            }
                            .aspectRatio(contentMode: animateView ? .fit : .fill)
                    }
                    .aspectRatio(contentMode: animateView ? .fit : .fill)
            }
            .aspectRatio(contentMode: animateView ? .fit : .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
    
    // TODO: this doesn't work when opening image
//    ProgressiveAsyncImage(urls: urls) { image in
//        image
//            .onSuccess { result in
//                onImageLoaded(result.image)
//            }
//            .contentConfigure { image in
//                image
//                    .resizable()
//                    .aspectRatio(contentMode: animateView ? .fit : .fill)
//                    .frame(width: size.width, height: size.height)
//                    .clipped()
//            }
//            
//    } placeholder: {
//        Color.clear
//    }
}
