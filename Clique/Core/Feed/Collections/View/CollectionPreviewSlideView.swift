//
//  CollectionPreviewSlideView.swift
//  Clique
//
//  Created by Kyuho Lee on 1/27/25.
//

import SwiftUI
import Kingfisher
import AdvancedList
import Toasts

struct CollectionPreviewSlideView: View {
    @Environment(\.presentToast) private var presentToast

    @Environment(UserStore.self) private var userStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CommentStore.self) private var commentStore

    let imageId: String
    let scrollPosition: String?

    /// Video quality preference
    @AppStorage("videoQualityPreference") private var videoQualityPreference: VideoQualityPreference = .auto

    @State private var commentsPgVM: CommentsPaginationViewModel

    @State private var likeAnimation: Bool = false
//    @State private var didLike: Bool
    @State private var offset = CGSize.zero

    @State private var showCommentSheet: Bool = false
    @State private var showLikedMembers: Bool = false

    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false

//    init(imageId: String) {
//        self.imageId = imageId
////        self._didLike = State(initialValue: image.hasLiked)
//    }

    init(imageId: String, scrollPosition: String?, _ commentStore: CommentStore, _ userStore: UserStore) {
        self.imageId = imageId
        self.scrollPosition = scrollPosition
        self.commentsPgVM = .init(collectionItemId: imageId, commentStore, userStore)
    }
    
    private var collectionImage: CollectionImage? {
        collectionImageStore.images[imageId]
    }
    
    var body: some View {
        collectionPreviewImage
            .overlay(alignment: .bottom) {
                overlayBar
            }
            .padding(.vertical, 32)
            .commentSheet(imageId: imageId, fromCollectionDetail: false, showCommentSheet: $showCommentSheet)
    }
    
    @ViewBuilder private var collectionPreviewImage: some View {
        if let collectionImage {
            Group {
                if collectionImage.isLivePhoto {
                    // Live Photo with native-like playback
                    // Always use high quality for live photo still images
                    // isInteractive: true so tap-and-hold plays, quick taps navigate
                    NetworkLivePhotoPlayerView(
                        imageUrl: collectionImage.imageUrl,
                        videoUrl: collectionImage.videoUrls,
                        quality: .high,
                        width: UIScreen.width - 32,
                        isInteractive: true
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if collectionImage.isVideo {
                    // Standalone video with auto-play (controlless in feed)
                    NetworkVideoPlayerView(
                        thumbnailUrl: collectionImage.imageUrl,
                        videoUrl: collectionImage.videoUrls,
                        quality: videoQualityPreference.imageQuality,
                        forceQuality: videoQualityPreference != .auto,
                        isVisible: scrollPosition == imageId,
                        width: UIScreen.width - 32,
                        showControls: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Regular static image
                    CollectionFeedCellAsyncImage(urls: collectionImage.imageUrl, width: UIScreen.width - 32, quality: .high)
                        .pinchZoom()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .doubleTapToLike(hasLiked: collectionImage.hasLiked, likeAnimation: $likeAnimation) {
                handleLikeTapped()
            }
            .onLongPressGesture {
                Task {
                    let users = try? await CollectionService.getLiked(.init(path: .init(collectionItemId: collectionImage.id), query: .init(page: 0, size: 5)))
                    print(users?.count ?? 0)
                }
            }
            .overlay {
                // like animation
                IconImage("heart-filled", color: .theme.red, size: 70)
                    .likeAnimation($likeAnimation)
            }
        }
    }
    
    @ViewBuilder private var overlayBar: some View {
        if let collectionImage {
            FeedCellBottomOverlay(
                listState: $listState,
                paginationState: $paginationState,
                isScrollAtBottom: $isScrollAtBottom,
                showSheet: $showCommentSheet,
                hasLiked: collectionImage.hasLiked,
                numLikes: collectionImage.numLikes,
                handleLikeTapped: handleLikeTapped,
                handleLikeCountTapped: { showLikedMembers = true },
                numComments: collectionImage.numComments,
                showCommentsPaging: !collectionImage.isVideo
            )
            .environment(commentsPgVM)
            .feedCellBottomOverlayModifiers()
            .maxWidth()
            .sheet(isPresented: $showLikedMembers) {
                LikedUsersListView(imageId: collectionImage.id, userStore)
                    .presentationDetents([.fraction(0.35), .fraction(0.999)])
                    .bottomSheetModifiers()
            }
        }
    }
    
    private func handleLikeTapped() {
        if let collectionImage {
            do {
                try handleCollectionImageLikeTapped(image: collectionImage, collectionImageStore)
            } catch {
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
}

//#Preview {
//    CollectionPreviewSlideView(image: ClCollection.MOCK_COLLECTIONS[0].images[0])
//}
