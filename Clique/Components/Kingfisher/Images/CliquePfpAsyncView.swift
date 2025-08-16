//
//  CliquePfpAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/2/25.
//

import SwiftUI
import Kingfisher

struct CliquePfpAsyncView: View {
    let pfp: PhotoUrls?
    let type: CliquePfpViewType
    var hasBorder: Bool = true
    let quality: ImageQuality
    
    var body: some View {
        if let pfp {
            GenericAsyncImage(urls: pfp, quality: quality) { image in
                image
                    .contentConfigure { image in
                        CliquePfpView(pfp: image, type: type, hasBorder: hasBorder)
                    }
            } placeholder: {
                Rectangle()
                    .fill(Color.theme.iconTertiary)
                    .frame(type.size)
                    .roundCorners(type.cornerRadius)
            }
        } else {
            Image("default-gradient")
                .cliquePfp(type: type, hasBorder: hasBorder)
        }
    }
}
