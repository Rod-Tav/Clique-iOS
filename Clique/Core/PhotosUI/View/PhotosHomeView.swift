//
//  PhotosHomeView.swift
//  Clique
//
//  Adapted from iOS18PhotosAppUI by Balaji Venkatesh
//

import SwiftUI

struct PhotosHomeView: View {
    var size: CGSize
    var safeArea: EdgeInsets
    var sharedData = PhotosSharedData()
    /// For knowing the direction of the scroll
    @State private var isMovingDown: Bool = false
    @State private var translationValue: CGFloat = 0

    var body: some View {
        let minimisedHeight = (size.height + safeArea.top + safeArea.bottom) * 0.4
        let mainOffset = sharedData.mainOffset

        ScrollView(.vertical) {
            VStack(spacing: 10) {
                PhotosGridScrollView(size: size, safeArea: safeArea)

                PhotosOtherContents()
                    .padding(.top, -30)
                    .offset(y: sharedData.progress * 30)
            }
            .offset(y: sharedData.canPullDown ? 0 : mainOffset < 0 ? -mainOffset : 0)
            .offset(y: mainOffset < 0 ? mainOffset : 0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self, of: {
            $0.contentOffset.y
        }, action: { oldValue, newValue in
            sharedData.mainOffset = newValue
        })
        .scrollDisabled(sharedData.isExpanded)
        .environment(sharedData)
        .onChange(of: translationValue) { oldValue, newValue in
            isMovingDown = oldValue < newValue
        }
        .gesture(
            PhotosCustomGesture(isEnabled: sharedData.activePage == 1) { gesture in
                let state = gesture.state
                let translation = gesture.translation(in: gesture.view).y
                let isScrolling = state == .began || state == .changed

                let mainOffset = sharedData.mainOffset
                let photosScrollOffset = sharedData.photosScrollOffset

                if state == .began {
                    sharedData.canPullDown = translation > 0 && (mainOffset >= 0 && mainOffset < 50)
                    sharedData.canPullUp = translation < 0 && (photosScrollOffset >= 0 && photosScrollOffset < 50)
                }

                if isScrolling {
                    if sharedData.canPullDown && !sharedData.isExpanded {
                        let progress = max(min(translation / minimisedHeight, 1), 0)
                        sharedData.progress = progress
                    }

                    if sharedData.canPullUp && sharedData.isExpanded {
                        let progress = max(min(-translation / minimisedHeight, 1), 0)
                        sharedData.progress = 1 - progress
                    }

                    translationValue = translation
                } else {
                    withAnimation(.smooth(duration: 0.35, extraBounce: 0)) {
                        if sharedData.canPullDown && !sharedData.isExpanded {
                            if translation > 0 && isMovingDown {
                                sharedData.isExpanded = true
                                sharedData.progress = 1
                            } else {
                                sharedData.progress = 0
                            }
                        }

                        if sharedData.canPullUp && sharedData.isExpanded {
                            if translation < 0 && !isMovingDown {
                                sharedData.isExpanded = false
                                sharedData.progress = 0
                            } else {
                                sharedData.progress = 1
                            }
                        }
                    }
                }
            }
        )
        .background(Color.theme.surfacesBackgroundPrimary)
    }
}
