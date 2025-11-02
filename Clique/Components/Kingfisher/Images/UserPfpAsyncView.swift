//
//  UserPfpAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/16/24.
//

import SwiftUI
import Kingfisher

struct UserPfpAsyncView: View {
    @Environment(UserStore.self) private var userStore

    var pfp: PhotoUrls?
    let size: CGFloat
    let quality: ImageQuality
    var context: ImageLoadingContext = .detail

    /// Smart context that auto-enables preloading for current user's profile picture.
    /// Current user's pfp should always load aggressively to avoid gray placeholders.
    private var effectiveContext: ImageLoadingContext {
        // If this is the current user's profile picture, always preload
        if let currentUserPfp = userStore.currentUser?.profilePic,
           pfp == currentUserPfp {
            return .list // Force preload for current user
        }
        return context
    }

    var body: some View {
        if let pfp {
            GenericAsyncImage(urls: pfp, quality: quality, context: effectiveContext) { image in
                image
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
