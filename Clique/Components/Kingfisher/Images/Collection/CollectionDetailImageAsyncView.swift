//
//  CollectionDetailImageAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

struct CollectionDetailImageAsyncView: View {
    let urls: PhotoUrls?
    let quality: ImageQuality
    
    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality) { image in
            image
                .contentConfigure { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                        .clipped()
                }
            
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
        }
    }
}
