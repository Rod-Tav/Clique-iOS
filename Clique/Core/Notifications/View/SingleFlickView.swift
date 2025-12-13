//
//  SingleFlickView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/2/25.
//

import SwiftUI
import Toasts
import AVFoundation

struct SingleFlickView: View {
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUpToOpenComments: Bool = false

    /// Video quality preference
    @AppStorage("videoQualityPreference") private var videoQualityPreference: VideoQualityPreference = .auto
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator

    @State private var dismissing: Bool = false
    @State private var dismissOffset: CGSize = .zero
    @State private var isZoomed: Bool = false
    
    @State private var likeAnimation: Bool = false
    
    @State private var showCommentSheet: Bool = false
    @State private var showLikedMembers: Bool = false
    
    let flick: CollectionImage
    let collection: ClCollection
    
    private var currentImage: CollectionImage? {
        collectionImageStore.images[flick.id]
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            topBar
            
            Spacer()
            
            flickView
            
            Spacer()
            
            belowFlick
        }
        // TODO: fromCollectionDetail is true because navigating to user profile is weird
        .commentSheet(imageId: flick.id, fromCollectionDetail: true, showCommentSheet: $showCommentSheet)
        .background {
            if let currentImage {
                CollectionDetailBackgroundAsyncImage(
                    urls: currentImage.imageUrl,
                    quality: .low,
                    uploadStatus: currentImage.uploadStatus,
                    itemId: currentImage.id,
                    isLivePhoto: currentImage.isLivePhoto,
                    isVideo: currentImage.isVideo
                )
                    .blur(radius: 12.5, opaque: true)
                    .overlay(Color.theme.surfacesImageBgDarkOverlay)
                    .overlay(.black.opacity(0.2))
            }
        }
    }

    // MARK: Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage(name: "x-icon", color: .theme.white, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: { headerContent },
            trailingIcon: { trailingMenu }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var trailingMenu: some View {
        // Only show menu for videos (video quality selector)
        if flick.isVideo {
            Menu {
                Menu {
                    ForEach(VideoQualityPreference.allCases, id: \.self) { quality in
                        Button {
                            videoQualityPreference = quality
                        } label: {
                            HStack {
                                Text(quality.displayName)
                                if videoQualityPreference == quality {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("Video Quality")
                    Image(systemName: "video.badge.waveform")
                }
            } label: {
                EllipsisImage(color: .theme.white, size: 24)
            }
        } else {
            Spacer().frame(24)
        }
    }
    
    private var headerContent: some View {
        Button {
            dismiss()
            tabViewCoordinator.navigate(to: collection)
        } label: {
            VStack(spacing: 2) {
                Group {
                    HStack(spacing: 4) {
                        Text(collection.name)
                            .font(.callout.bold())
                        
                        if collection.visibility == .priv {
                            IconImage(
                                name: "lock",
                                color: .theme.shadesWhite95,
                                size: 16
                            )
                            .padding(.leading, 2)
                        }

                        IconImage(name: "chevron-right", color: .theme.iconPrimary, size: 16)
                    }

                    DateMediaTypeLabel(
                        image: flick,
                        dateFormat: .full,
                        fontSize: .caption,
                        textColor: .theme.white
                    )
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.theme.white)
            }
            .contentShape(.rect)
        }
        .noHighlight()
    }
    
    // MARK: Flick View
    private var flickView: some View {
        ZoomContainer {
            CollectionDetailImageAsyncView(
                image: flick,
                quality: videoQualityPreference.imageQuality,
                forceQuality: videoQualityPreference != .auto,
                isVisible: true
            )
                .doubleTapToLike(hasLiked: currentImage?.hasLiked ?? false, likeAnimation: $likeAnimation) {
                    handleLikeTapped()
                }
                .if(!flick.isVideo && !flick.isLivePhoto) { view in
                    view.pinchZoom(isZoomed: $isZoomed)  // Only apply pinch zoom to static photos (not videos or Live Photos)
                }
                .swipeUpToOpenCommentsTutorial()
                .compatibleDragGesture(
                    minimumDistance: GestureConstants.minimumRecognitionDistance,
                    onChanged: { translation in
                        guard !dismissing else { return }
                        // Check if the swipe was mostly vertical and upwards
                        if translation.height < -GestureConstants.minimumUpwardSwipeForAction && abs(translation.width) < GestureConstants.maximumHorizontalDeviation {
                            haptics(.light)
                            showCommentSheet = true
                            hasSwipedUpToOpenComments = true
                        }
                    },
                    onEnded: { _, _ in }  // Required for CompatibleDragGestureModifier signature
                )
                .offset(dismissOffset)
                .compatibleDragGesture(
                    minimumDistance: GestureConstants.minimumRecognitionDistance,
                    onChanged: { translation in
                        guard !isZoomed else { return }
                        guard (translation.height > GestureConstants.minimumVerticalSwipe && abs(translation.width) < GestureConstants.maximumHorizontalDeviation) || dismissing else { return }

                        dismissing = true
                        dismissOffset = CGSize(width: 0, height: translation.height)
                    },
                    onEnded: { translation, velocity in
                        guard dismissing else { return }
                        // Include velocity for flick detection
                        let height = translation.height + (velocity.height / GestureConstants.velocityDampening)

                        if height > GestureConstants.dismissThresholdWithVelocity {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissOffset = .zero
                            } completion: {
                                dismissing = false
                            }
                        }
                    }
                )
                .overlay {
                    IconImage(name: "heart-filled", color: .theme.red, size: 70)
                        .likeAnimation($likeAnimation)
                }
        }
    }
    
    // MARK: Below Flick
    private var belowFlick: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                Button {
                    tabViewCoordinator.focusCommentKeyboard = true
                    showCommentSheet = true
                } label: {
                    ZStack(alignment: .leading) {
                        if let currentUser = userStore.currentUser {
                            UserPfpAsyncView(pfp: currentUser.profilePic, size: 32, quality: .low)
                                .zIndex(1)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Add a comment...")
                                .font(.footnote)
                                .foregroundColor(Color.theme.white)
                                .maxWidth(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .roundCorners(16)
                        .maxWidth()
                        .offset(x: 32-8)
                        .padding(.trailing, 32-8)
                    }
                    .maxWidth(.leading)
                }.buttonStyle(.noHighlight)
                
                if let currentImage {
                    HStack(spacing: 6) { // TODO: DRY
                        Button {
                            haptics(.medium)
                            handleLikeTapped()
                        } label: {
                            IconImage(name: "heart-filled", color: currentImage.hasLiked ? .theme.red : .theme.white, size: 28)
                        }
                        
                        Button {
                            showLikedMembers = true
                        } label: {
                            Text(formatNumber(currentImage.numLikes))
                                .font(.footnote.bold())
                                .foregroundStyle(Color.theme.white)
                        }
                    }
                    .sheet(isPresented: $showLikedMembers) {
                        LikedUsersListView(imageId: currentImage.id, fromCollectionDetail: true, userStore)
                            .presentationDetents([.fraction(0.35), .fraction(0.999)])
                            .bottomSheetModifiers()
                    }
                    
                    Button {
                        showCommentSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            IconImage(name: "comment-filled", color: .theme.white, size: 28)
                            
                            Text(formatNumber(currentImage.numComments))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.theme.white)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: Helpers
private extension SingleFlickView {
    func handleLikeTapped() {
        do {
            try handleCollectionImageLikeTapped(image: flick, collectionImageStore)
        } catch {
            presentToast(Toasts.somethingWentWrong)
        }
    }
}
