//
//  UserPfpAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/16/24.
//

import SwiftUI
import Kingfisher

struct UserPfpAsyncView: View {
    var pfp: PhotoUrls?
    let size: CGFloat
    let quality: ImageQuality
    var loadingBug: Bool = true
    
    var body: some View {
        if let pfp {
            GenericAsyncImage(urls: pfp, quality: quality, loadingBug: loadingBug) { image in
                image
                    .kfModifiers(shouldFade: quality == .high, loadingBug: loadingBug)
                    .contentConfigure { image in
                        image
                            .userPfp(size: size)
                    }
                
            } placeholder: {
                Circle()
                    .fill(Color.theme.iconTertiary)
                    .frame(size)
            }
        } else {
            Image("default-gradient")
                .userPfp(size: size)
        }
    }
}

extension Image {
    func userPfp(size: CGFloat) -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(size)
            .clipShape(.circle)
            .overlay(
                Circle()
                    .inset(by: -0.25)
                    .stroke(Color.theme.strokeTertiary, lineWidth: 0.5)
            )
    }
}
