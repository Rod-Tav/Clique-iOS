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
    let collectionId: String  // Collection this image belongs to
    let scrollPosition: String?
    let onRefresh: (() -> Void)?

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

    init(imageId: String, collectionId: String, scrollPosition: String?, _ commentStore: CommentStore, _ userStore: UserStore, onRefresh: (() -> Void)? = nil) {
        self.imageId = imageId
        self.collectionId = collectionId
        self.scrollPosition = scrollPosition
        self.onRefresh = onRefresh
        self.commentsPgVM = .init(collectionItemId: imageId, commentStore, userStore)
    }
    
    private var collectionImage: CollectionImage? {
        collectionImageStore.images[imageId]
    }
    
    private let previewQuality: ImageQuality = .medium
    
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
                if collectionImage.uploadStatus == .PENDING {
                    // PENDING: Show device photo with correct sizing (falls back to S3 on cache miss)
                    PendingFeedCellImage(
                        itemId: collectionImage.id,
                        width: UIScreen.width - 32,
                        collectionDataId: collectionId,
                        fallbackUrl: collectionImage.imageUrl
                    )
                } else if collectionImage.isLivePhoto {
                    // Live Photo with native-like playback
                    // Always use high quality for live photo still images
                    // isInteractive: true so tap-and-hold plays, quick taps navigate
                    NetworkLivePhotoPlayerView(
                        imageUrl: collectionImage.imageUrl,
                        videoUrl: collectionImage.videoUrls,
                        quality: previewQuality,
                        width: UIScreen.width - 32,
                        isInteractive: true
                    )
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
                } else {
                    // Regular static image
                    CollectionFeedCellAsyncImage(urls: collectionImage.imageUrl, width: UIScreen.width - 32, quality: previewQuality, uploadStatus: collectionImage.uploadStatus, itemId: collectionImage.id, onRefresh: onRefresh)
                        .pinchZoom()
                }
            }
            .roundCorners(8)
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
                IconImage(name: "heart-filled", color: .theme.red, size: 70)
                    .likeAnimation($likeAnimation)
            }
            .overlay(alignment: .center) {
                // Processing overlay for live photos/videos only (static images handle it internally)
                if (collectionImage.isLivePhoto || collectionImage.isVideo) {
                    if collectionImage.uploadStatus == .PENDING, let onRefresh = onRefresh {
                        UploadStatusOverlay(
                            status: collectionImage.uploadStatus,
                            onRefresh: onRefresh
                        )
                    } else if collectionImage.uploadStatus == .FAILED {
                        UploadStatusOverlay(status: collectionImage.uploadStatus, onRefresh: onRefresh)
                    }
                }
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

import Photos

/// Helper view to load PENDING device images in feed cells
private struct PendingFeedCellImage: View {
    @Environment(CollectionStore.self) private var collectionStore

    let itemId: String
    let width: CGFloat
    let collectionDataId: String
    let fallbackUrl: PhotoUrls?

    @State private var deviceAsset: PHAsset?
    @State private var isLoading: Bool = true
    @State private var deviceLoadFailed: Bool = false

    var body: some View {
        Group {
            if let asset = deviceAsset, !deviceLoadFailed {
                FeedCellDeviceImageView(asset: asset, width: width)
            } else if deviceLoadFailed {
                // Fallback to S3 on cache miss (e.g., different device, deleted photos)
                CollectionFeedCellAsyncImage(
                    urls: fallbackUrl,
                    width: width,
                    quality: .medium,
                    uploadStatus: nil,
                    itemId: itemId,
                    onRefresh: {}
                )
            } else {
                // Loading state
                Rectangle()
                    .fill(Color.theme.iconTertiary)
                    .frame(width: width, height: width)
                    .roundCorners(8)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            }
        }
        .id(itemId)  // Stable identity prevents state reset when scrollPosition changes
        .task {
            await loadDeviceAsset()
        }
    }

    @MainActor
    private func loadDeviceAsset() async {
        isLoading = true

        // Check AppStorage cache for asset mapping
        guard let cachedInfo = PendingImageCache.shared.get(itemId) else {
            print("⚠️ [FEED-PENDING] No cache entry for itemId: \(itemId) - falling back to S3")
            isLoading = false
            deviceLoadFailed = true
            return
        }

        // Fetch PHAsset from device
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [cachedInfo.assetIdentifier],
            options: nil
        )

        guard let foundAsset = fetchResult.firstObject else {
            print("⚠️ [FEED-PENDING] Asset not found (deleted?): \(cachedInfo.assetIdentifier) - falling back to S3")
            PendingImageCache.shared.remove(itemId)
            isLoading = false
            deviceLoadFailed = true
            return
        }

        print("✅ [FEED-PENDING] Loaded device photo for itemId: \(itemId)")
        self.deviceAsset = foundAsset
        isLoading = false

        // Prefetch adjacent items to avoid flash on swipe
        prefetchAdjacentItems()
    }

    private func prefetchAdjacentItems() {
        // Get all image IDs from the collection
        guard let collection = collectionStore.collections[collectionDataId] else { return }
        let allItemIds = collection.images.map { $0.id }

        guard let currentIndex = allItemIds.firstIndex(of: itemId) else { return }

        // Get next 3 items after current
        let startIndex = currentIndex + 1
        let endIndex = min(currentIndex + 4, allItemIds.count)
        guard startIndex < allItemIds.count else { return }

        let adjacentIds = Array(allItemIds[startIndex..<endIndex])

        // Get PHAssets for adjacent PENDING items
        var assetsToPrefetch: [PHAsset] = []
        for id in adjacentIds {
            guard let cachedInfo = PendingImageCache.shared.get(id) else { continue }

            let fetchResult = PHAsset.fetchAssets(
                withLocalIdentifiers: [cachedInfo.assetIdentifier],
                options: nil
            )

            if let asset = fetchResult.firstObject {
                assetsToPrefetch.append(asset)
            }
        }

        // Prefetch into DeviceImageCache
        if !assetsToPrefetch.isEmpty {
            DeviceImageCache.shared.prefetch(assets: assetsToPrefetch, width: width)
        }
    }
}

//#Preview {
//    CollectionPreviewSlideView(image: ClCollection.MOCK_COLLECTIONS[0].images[0])
//}
