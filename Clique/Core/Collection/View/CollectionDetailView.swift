//
//  CollectionDetailView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/16/24.
//

import SwiftUI
import Toasts
import Kingfisher
import AdvancedList
import AVFoundation

struct CollectionDetailView: View {
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUpToOpenComments: Bool = false
    
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CommentStore.self) private var commentStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(CollectionCoordinator.self) private var clCoordinator
    @Environment(HeroCoordinator.self) private var heroCoordinator
    @Environment(TabViewCoordinator.self) private var tabCoordinator
    @Environment(CollectionImagesPaginationViewModel.self) private var imagesPgVM
    
    @State private var opacity: CGFloat = 1
    @State private var dismissing: Bool = false
//    @State var selectedImageId: String?
    
    @State private var showCommentSheet: Bool = false
    @State private var showReportCover: Bool = false
    //    @State private var scrollProgress: CGFloat = 0
    @State private var showSwipeTutorial: Bool = false
    @State private var showDeleteFlickAlert: Bool = false
    @State private var showLikedMembers: Bool = false
    
    @State private var isScrolling: Bool = false

    @State private var likeAnimation: Bool = false

    /// Video quality preference
    @AppStorage("videoQualityPreference") private var videoQualityPreference: VideoQualityPreference = .auto

    /// Live Photo save state
    @State private var isSavingLivePhoto: Bool = false

    /// self tagging
    @State private var confirmed: Bool = false
    @State private var shouldFadeOut: Bool = false
    @State private var isButtonDisabled: Bool = false
    @State private var selfTaggedImages = [String]() // image ids

    /// Video playback position preservation
    @State private var videoPlaybackPositions: [String: CMTime] = [:]

    private var selectedImageId: String? {
        clCoordinator.selectedImageId
    }
    
    var selectedImage: CollectionImage? {
        if let selectedImageId {
            return collectionImageStore.images[selectedImageId]
        } else {
            return nil
        }
    }
    
    private var isSelfTagged: Bool {
        selfTaggedImages.contains(where: { $0 == selectedImageId })
    }
    
    var collection: ClCollection? {
        collectionStore.collections[clCoordinator.collectionId]
    }
    
    var cid: String? {
       collection?.cliqueId
    }
    
    @State var loadedImage: UIImage?
    
    var fromGallery: Bool = true
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableImageStore = collectionImageStore
        
        ZoomContainer {
            VStack(spacing: 0) {
                TopBar()
                    .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
                
                Spacer()
                
                ImageDetail()
                    .opacity(heroCoordinator.showDetailView ? 1 : 0)
                
                Spacer(minLength: 0)
                
                VStack(spacing: 32) {
                    BottomIndicatorView()
                    //                        .overlay(alignment: .top) {
                    ////                            if !isSelfTagged {
                    //                                SelfTagButton()
                    //                                    .offset(y: -46)
                    ////                            }
                    //                        }
                    
                    BottomActionBar()
                    
                }
                .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
            }
            //        .opacity(coordinator.showDetailView ? 1 : 0)
            .onAppear {
                // Mark pagination view model as detail view for high quality prefetching
                imagesPgVM.isDetailView = true

                tabCoordinator.pan = .disabled
                if fromGallery {
                    tabCoordinator.showTabBar = false
                }
                clCoordinator.toggleView(show: true)
                if fromGallery {
                    heroCoordinator.toggleView(show: true)
                } else {
                    // For feed presentation, we need immediate display without hero animation
                    withAnimation(.snappy(duration: 0.3)) {
                        heroCoordinator.animateView = true
                        heroCoordinator.showDetailView = true
                    }
                    heroCoordinator.animationIsOpen = true
                }
            }
            .onDisappear {
                tabCoordinator.pan = .pan
                // Ensure dismissing flag is reset to prevent stale state
                dismissing = false
                // Reset pagination view model state
                imagesPgVM.isDetailView = false
            }
            .background {
                if let selectedImage {
                    CollectionDetailBackgroundAsyncImage(
                        urls: selectedImage.imageUrl,
                        quality: .low,
                        uploadStatus: selectedImage.uploadStatus,
                        itemId: selectedImage.id,
                        isLivePhoto: selectedImage.isLivePhoto,
                        isVideo: selectedImage.isVideo
                    )
                        .blur(radius: 12.5 /*- (10 * ((idx + 1) - diff))*/, opaque: true)
                        .overlay(Color.theme.surfacesImageBgDarkOverlay)
                        .overlay(.black.opacity(0.2))
                        .opacity(heroCoordinator.animateView ? /*((idx + 1) - diff)*/ 1 - heroCoordinator.dragProgress : 0)
                        .background(Color.theme.black.opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0))
                }
            }
            .commentSheet(imageId: selectedImageId, fromCollectionDetail: true, showCommentSheet: $showCommentSheet)
            .swipeUpToOpenCommentsTutorial()
        }
    }
}

// MARK: - TopBar
extension CollectionDetailView {
    @ViewBuilder func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    closeImage()
                } label: {
                    IconImage(name: "arrow-left", color: .theme.white, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: HeaderContent,
            trailingIcon: {
                Menu {
                    // Video quality selector (only for videos)
                    if selectedImage?.isVideo == true {
                        Menu {
                            ForEach(VideoQualityPreference.allCases, id: \.self) { quality in
                                Button {
                                    videoQualityPreference = quality
                                    print("🎬 [QUALITY] User selected: \(quality.displayName)")
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
                                .color(.theme.iconPrimary)
                        }
                    }

                    if let cid, isInClique(cid: cid, cliqueStore), let loadedImage {
                        ShareLink(
                            item: Image(uiImage: loadedImage),
                            preview: SharePreview("", image: Image(uiImage: loadedImage))
                        ) {
                            Text("Share Image")

                            Image("share")
                                .color(.theme.iconPrimary)
                        }

                        // Save button (conditional based on media type)
                        if let selectedImage = selectedImage {
                            if selectedImage.isLivePhoto {
                                // Save Live Photo with metadata injection (falls back to video if metadata fails)
                                Button {
                                    handleSaveLivePhoto()
                                } label: {
                                    HStack {
                                        Text(isSavingLivePhoto ? "Saving..." : "Save Live Photo")
                                        if !isSavingLivePhoto {
                                            Image("download")
                                                .color(.theme.iconPrimary)
                                        } else {
                                            ProgressView()
                                                .tint(.theme.iconPrimary)
                                        }
                                    }
                                }
                                .disabled(isSavingLivePhoto)
                            } else if selectedImage.isVideo {
                                // Save Video
                                Button {
                                    handleSaveVideo()
                                } label: {
                                    Text("Save Video")
                                    Image("download")
                                        .color(.theme.iconPrimary)
                                }
                            } else {
                                // Save static image
                                Button {
                                    handleSaveImage()
                                } label: {
                                    Text("Save Image")
                                    Image("download")
                                        .color(.theme.iconPrimary)
                                }
                            }
                        }

                        DeleteButton {
                            showDeleteFlickAlert = true
                        }
                    }

                    ReportButton {
                        showReportCover = true
                    }
                } label: {
                    EllipsisImage(color: .theme.white, size: 24)
                }
                .alert(isPresented: $showDeleteFlickAlert) {
                    Alert(
                        title: Text("Are you sure you want to delete this flick?"),
                        message: Text("This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            handleDeleteFlick()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .task {
            guard let url = selectedImage?.imageUrl?.highQualityUrl, let cid, isInClique(cid: cid, cliqueStore) else { return }
            
            loadedImage = await fetchImageWithKingfisher(from: url)
        }
        .fullScreenCover(isPresented: $showReportCover) {
            if let selectedImage {
                ReportView(showReport: $showReportCover, objectId: selectedImage.id, reportType: .image)
            }
        }
        //        .offset(y: coordinator.showDetailBars ? (-110 * coordinator.dragProgress) : -110)
        //        .animation(.easeInOut(duration: 0.3), value: coordinator.showDetailBars)
        //        .opacity(coordinator.showDetailBars && !coordinator.hideDetailBars ? 1 - coordinator.dragProgress : 0)
        //        .animation(.easeInOut(duration: 0.2), value: coordinator.showDetailBars)
        //        .animation(.easeInOut(duration: 0.2), value: coordinator.hideDetailBars)
    }
    
    @ViewBuilder private func HeaderContent() -> some View {
        Button {
            guard !fromGallery, let collection else { return }

            dismiss()
            tabCoordinator.navigate(to: collection)
        } label: {
            VStack(spacing: 2) {
                Group {
                    if let collectionName = collection?.name {
                        HStack(spacing: 4) {
                            Text(collectionName)
                                .font(.callout.bold())

                            if !fromGallery {
                                IconImage(
                                    name: "chevron-right",
                                    color: Color.theme.white,
                                    size: 16
                                )
                            }
                        }
                    }

                    // Date, time, and media type inline
                    if let selectedImage {
                        DateMediaTypeLabel(
                            image: selectedImage,
                            dateFormat: .full,
                            fontSize: .caption,
                            textColor: .theme.white
                        )
                    }
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.theme.white)
            }
            .contentShape(.rect)
        }
        .noHighlight()
    }
}

// MARK: - Image
extension CollectionDetailView {
    @ViewBuilder private func ImageDetail() -> some View {
        if let selectedImage {
            @Bindable var bindableVM = clCoordinator
            
            //        let screenWidth = UIScreen.width
            ZStack {
                /// hero close (only render when actually dismissing to avoid duplicate video players)
                if dismissing {
                    CollectionDetailImageAsyncView(
                        image: selectedImage,
                        quality: videoQualityPreference.imageQuality,
                        forceQuality: videoQualityPreference != .auto,
                        isVisible: true,
                        onRefresh: refreshCollection
                    )
                        .contentShape(.rect)
                }

                    AdvancedList(imagesPgVM.items, listView: { images in
                        ImageDetailList(images)
                    }, content: { imageID in
                        if let image = collectionImageStore.images[imageID] {
                            ImageDetailCell(image)
                        }
                    }, listState: clCoordinator.listState, emptyStateView: {
                        EmptyStateView()
                    }, errorStateView: { _ in
                        ErrorStateView()
                    }, loadingStateView: {
                        LoadingStateView()
                    })
//                    .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateImages(.loadNextPage) } }) { })
//                    .task {
//                        guard clCoordinator.listState == .loading else { return }
//                        await updateImages(.loadFirstPage)
//                    }
                    .onChange(of: clCoordinator.detailScrollPosition) { oldValue, newValue in
                        guard !dismissing else { return }
                        if isScrolling {
                            clCoordinator.selectedImageId = newValue
                        } else {
                            withAnimation(.snappy) {
                                clCoordinator.selectedImageId = newValue
                            }
                        }
                    }
                    .onChange(of: selectedImageId) { oldValue, newValue in
                        guard !dismissing, let newValue else { return }
                        
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
                            if newValue == selectedImageId { // Ensure the value is still the latest
                                scrollCarousel(to: newValue)
                            }
                        }
                    }
                    .infiniteFrame()
                    .opacity(dismissing ? 0 : 1)
                    .doubleTapToLike(hasLiked: selectedImage.hasLiked, likeAnimation: $likeAnimation) {
                        handleLikeTapped()
                    }
                    .overlay {
                        IconImage(name: "heart-filled", color: .theme.red, size: 70)
                            .likeAnimation($likeAnimation)
                    }
            }
            .background {
                Rectangle()
                    .fill(.clear)
                    .anchorPreference(key: HeroKey.self, value: .bounds, transform: { anchor in
                        guard let url = selectedImage.imageUrl?.highQualityUrl else { return [:] }
                        return [url + "DEST": anchor]
                    })
                    .frameRatio(width: UIScreen.width, ratio: Constants.collectionImageDetailRatio)
            }
            .offset(heroCoordinator.offset)
            .compatibleDragGesture(
                minimumDistance: GestureConstants.minimumRecognitionDistance,
                onChanged: { translation in
                    guard (translation.height > GestureConstants.minimumVerticalSwipe && abs(translation.width) < GestureConstants.maximumHorizontalDeviation) || dismissing else { return }
                    dismissing = true
                    heroCoordinator.offset = fromGallery ? translation : CGSize(width: 0, height: translation.height)
                    /// Progress For Fading Out the Detail View
                    let heightProgress = max(min(translation.height / GestureConstants.dragProgressDivisor, 1), 0)
                    heroCoordinator.dragProgress = heightProgress
                },
                onEnded: { translation, velocity in
                    guard dismissing else { return }

                    /// Close the View based on drag distance OR velocity (for flick gestures)
                    let height = translation.height + (velocity.height / GestureConstants.velocityDampening)

                    if height > GestureConstants.dismissThresholdWithVelocity {
                        closeImage()
                    } else {
                        /// Reset to its Initial Position
                        heroCoordinator.offset = .zero
                        heroCoordinator.dragProgress = 0
                        dismissing = false
                    }
                }
            )
            .compatibleDragGesture(
                minimumDistance: 10,
                onChanged: { translation in
                    guard heroCoordinator.offset == .zero else { return }
                    // Check if the swipe was mostly vertical and upwards
                    if translation.height < -20 && abs(translation.width) < 20 {
                        haptics(.light)
                        showCommentSheet = true
                        hasSwipedUpToOpenComments = true
                    }
                },
                onEnded: { _, _ in }  // Required for CompatibleDragGestureModifier signature
            )
        }
    }
    
    @ViewBuilder private func ImageDetailList(_ rows: AdvancedList.Rows) -> some View {
        @Bindable var bindableVM = clCoordinator
        
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12, content: rows)
                .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $bindableVM.detailScrollPosition)
        .scrollDisabled(dismissing)
        .onChange(of: bindableVM.detailScrollPosition) { _, newValue in
            // Prefetch adjacent images when scrolling
            guard let newValue,
                  let currentIndex = imagesPgVM.items.firstIndex(where: { $0.id == newValue }) else { return }

            // Get 2 images before and 2 after current image
            let startIndex = max(0, currentIndex - 2)
            let endIndex = min(imagesPgVM.items.count - 1, currentIndex + 2)
            let adjacentIds = Array(imagesPgVM.items[startIndex...endIndex])
            let adjacentImages = adjacentIds.compactMap { collectionImageStore.images[$0] }

            CollectionImagePrefetcher.instance.prefetchForContext(
                .detailView,
                collectionId: clCoordinator.collectionId,
                images: adjacentImages
            )
        }
    }
    
    @ViewBuilder private func ImageDetailCell(_ image: CollectionImage) -> some View {
        CollectionDetailImageAsyncView(
            image: image,
            quality: videoQualityPreference.imageQuality,
            forceQuality: videoQualityPreference != .auto,
            isVisible: selectedImageId == image.id,
            onRefresh: refreshCollection,
            savedPosition: videoPlaybackPositions[image.id],
            onPositionSave: { time in
                videoPlaybackPositions[image.id] = time
            }
        )
            .contentShape(.rect)
            .id(image.id)
            .if(!image.isVideo && !image.isLivePhoto) { view in
                view.pinchZoom()  // Only apply pinch zoom to static photos (not videos or Live Photos)
            }
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.7)
                    .scaleEffect(phase.isIdentity ? 1 : 0.85)
                //                                    .blur(radius: phase.isIdentity ? 0 : 10)
            }
    }
    
    @ViewBuilder private func SelfTagButton() -> some View {
        Button {
            guard !isButtonDisabled else { return }
            isButtonDisabled = true
            
            selfTaggedImages.append(clCoordinator.selectedImageId!)
            if isSelfTagged {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    confirmed = isSelfTagged
                    if confirmed {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut) {
                                shouldFadeOut = true
                            }
                        }
                    }
                }
            } else {
                confirmed = false
                shouldFadeOut = false // Reset fade-out when untagged
            }
        } label: {
            HStack(spacing: 8) {
                Image(isSelfTagged ? "check" : "camera")
                    .icon(color: .theme.shadesWhite95, size: 16)
                
                if !confirmed {
                    Text(isSelfTagged ? "Tagged" : "Tag yourself")
                        .font(.caption)
                        .foregroundStyle(Color.theme.shadesWhite95)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, confirmed ? 8 : 10)
            .background(isSelfTagged ? Color.theme.green : .gray) // TODO: color that works
            .roundCorners(32)
            .animation(.easeInOut(duration: 0.3), value: confirmed)
            .animation(.easeInOut(duration: 0.4), value: isSelfTagged)
        }
        .opacity(shouldFadeOut ? 0 : 1)
        .onChange(of: clCoordinator.selectedImageId) {
            confirmed = false
            shouldFadeOut = false
            isButtonDisabled = false
        }
        .disabled(isButtonDisabled)
    }

    // MARK: - Helper Functions

    /// Triggers a refresh of the collection to update processing status
    private func refreshCollection() {
        trigger(.refreshCollectionImages, object: [clCoordinator.collectionId])
    }
}

// MARK: - Bottom Carousel
extension CollectionDetailView {
    @ViewBuilder private func BottomIndicatorView() -> some View {
        if let selectedImage {
            let hSpacing: CGFloat = 4
            let centerImageSpacing: CGFloat = 8 - hSpacing
            let centerImageWidth = UIScreen.width / ScaleFactors.collectionCarouselSelectedItem
            let sideImageWidth = (UIScreen.width - centerImageWidth - (hSpacing * 12)) / 8
            let sideImageHeight = sideImageWidth / Constants.collectionCarouselRatio
            let centerImageHeight = centerImageWidth / Constants.collectionCarouselSelectedRatio
            
            AdvancedList(imagesPgVM.items, listView: { images in
                BottomCarouselList(images, hSpacing: hSpacing)
            }, content: { imageID in
                if let image = collectionImageStore.images[imageID] {
                    let isSelected = image.imageUrl == selectedImage.imageUrl
                    
                    BottomCarouselCell(
                        image,
                        width: (isSelected && !isScrolling) ? centerImageWidth : sideImageWidth,
                        height: (isSelected && !isScrolling) ? centerImageHeight : sideImageHeight
                    )
                    .padding(.horizontal, (isSelected && !isScrolling) ? centerImageSpacing : 0)
                }
            }, listState: clCoordinator.listState, emptyStateView: {
                EmptyStateView()
            }, errorStateView: { _ in
                ErrorStateView()
            }, loadingStateView: {
                LoadingStateView()
            })
//            .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateImages(.loadNextPage) } }) { })
//            .task {
//                guard clCoordinator.listState == .loading else { return }
//                await updateImages(.loadFirstPage)
//            }
            .onChange(of: clCoordinator.detailIndicatorPosition) { oldValue, newValue in
                if let newValue {
                    clCoordinator.didDetailIndicatorPageChanged(updatedImageId: newValue)
                }
            }
            .frame(height: centerImageHeight)
            .safeAreaPadding(.horizontal, (UIScreen.width - centerImageWidth - (centerImageSpacing * 2)) / 2)
        }
    }
    
    @ViewBuilder private func BottomCarouselList(_ rows: AdvancedList.Rows, hSpacing: CGFloat) -> some View {
        @Bindable var bindableClCoordinator = clCoordinator
        
        ScrollView(.horizontal) {
            LazyHStack(spacing: hSpacing, content: rows)
                .scrollTargetLayout()
        }
        .isInteracting($isScrolling)
        .scrollTargetBehavior(.viewAligned)
        //            .scrollPosition(id: .init(get: {
        //                return clCoordinator.detailIndicatorPosition
        //            }, set: {
        //                clCoordinator.detailIndicatorPosition = $0
        //            }))
        .scrollPosition(id: $bindableClCoordinator.detailIndicatorPosition)
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder private func BottomCarouselCell(_ image: CollectionImage, width: CGFloat, height: CGFloat) -> some View {
        if let selectedImage {
            CollectionBottomCarouselAsyncView(
                urls: image.imageUrl,
                width: width,
                height: height,
                quality: .low,
                uploadStatus: image.uploadStatus,
                itemId: image.id,
                isLivePhoto: image.isLivePhoto,
                isVideo: image.isVideo
            )

            // TODO: rework
                .if(heroCoordinator.showDetailView) { view in
                    view
                        .animation(.snappy, value: (image.imageUrl == selectedImage.imageUrl && !isScrolling))
                }
                .animation(.snappy, value: !isScrolling)
                .onTapGesture {
                    scrollCarousel(to: image.id)
                }
        }
    }
    
    private func updateImages(_ operation: PaginationOperationType) async {
        @Bindable var bindableClCoordinator = clCoordinator
        
        await PaginationHelper.updateItems(
            operation,
            viewModel: imagesPgVM,
            listState: $bindableClCoordinator.listState,
            paginationState: $bindableClCoordinator.paginationState,
            isScrollAtBottom: $bindableClCoordinator.isScrollAtBottom
        )
    }
    
    // TODO: fix
    private func scrollCarousel(to id: String) {
        clCoordinator.detailScrollPosition = id
        clCoordinator.didDetailPageChanged(updatedImageId: id)
        
        if fromGallery, let updatedImageUrls = collectionImageStore.images[id]?.imageUrl {
            heroCoordinator.imageUrls = updatedImageUrls
        }
    }
    
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
//            .padding(.horizontal, 16)
//            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            clCoordinator.listState = .loading
            await updateImages(.refresh)
        }
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
}

// MARK: - Bottom Action Bar
extension CollectionDetailView {
    @ViewBuilder private func BottomActionBar() -> some View {
        if let selectedImage {
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Button {
                        haptics(.medium)
                        handleLikeTapped()
                    } label: {
                        IconImage(name: "heart-filled", color: selectedImage.hasLiked ? .theme.red : .theme.white, size: 20)
                    }
                    
                    Button {
                        showLikedMembers = true
                    } label: {
                        Text(formatNumber(selectedImage.numLikes))
                            .font(.footnote.bold())
                            .foregroundStyle(Color.theme.white)
                    }
                }
                .sheet(isPresented: $showLikedMembers) {
                    LikedUsersListView(imageId: selectedImage.id, fromCollectionDetail: true, userStore)
                        .presentationDetents([.fraction(0.35), .fraction(0.999)])
                        .bottomSheetModifiers()
                }
                
                Button {
                    showCommentSheet = true
                } label: {
                    BottomActionItem(
                        icon: "comment-filled",
                        number: selectedImage.numComments
                    )
                }
                
                Button {
                    tabViewCoordinator.focusCommentKeyboard = true
                    showCommentSheet = true
                } label: {
                    ZStack(alignment: .leading) {
                        if let pfp = userStore.currentUser?.profilePic {
                            UserPfpAsyncView(pfp: pfp, size: 32, quality: .low)
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .maxWidth()
        }
    }
    
    @ViewBuilder private func BottomActionItem(
        icon: String,
        iconColor: Color = .theme.white,
        number: Int
    ) -> some View {
        HStack(spacing: 4) {
            IconImage(name: icon, color: iconColor, size: 20)
            
            Text(formatNumber(number))
                .font(.footnote.bold())
                .foregroundStyle(Color.theme.white)
        }
    }
}

// MARK: - Helpers
extension CollectionDetailView {
    private func handleLikeTapped() {
        if let selectedImage {
            do {
                try handleCollectionImageLikeTapped(image: selectedImage, collectionImageStore)
            } catch {
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }

    /// Handles saving a Live Photo with metadata injection
    private func handleSaveLivePhoto() {
        guard !isSavingLivePhoto, let selectedImage else { return }

        Task {
            await CollectionImageSaveHelpers.saveLivePhoto(
                image: selectedImage,
                collectionImageStore: collectionImageStore,
                isSavingLivePhoto: &isSavingLivePhoto,
                presentToast: presentToast
            )
        }
    }

    /// Handles saving a standalone video
    private func handleSaveVideo() {
        guard let selectedImage else { return }

        Task {
            await CollectionImageSaveHelpers.saveVideo(
                image: selectedImage,
                presentToast: presentToast
            )
        }
    }

    /// Handles saving a static image
    private func handleSaveImage() {
        guard let selectedImage else { return }

        Task {
            await CollectionImageSaveHelpers.saveImage(
                image: selectedImage,
                presentToast: presentToast
            )
        }
    }

    /// Handles deleting the current flick
    private func handleDeleteFlick() {
        guard let selectedImageId else { return }

        Task {
            await CollectionImageSaveHelpers.deleteCollectionItem(
                imageId: selectedImageId,
                collectionId: clCoordinator.collectionId,
                collectionStore: collectionStore,
                collectionImageStore: collectionImageStore,
                presentToast: presentToast,
                onSuccess: {
                    closeImage()
                    imagesPgVM.items.removeAll(where: { $0.id == selectedImageId })
                }
            )
        }
    }
    
    private var swipeUpToOpenComments: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard heroCoordinator.offset == .zero else { return }
                // Check if the swipe was mostly vertical and upwards
                if value.translation.height < -20 && abs(value.translation.width) < 20 {
                    haptics(.light)
                    showCommentSheet = true
                    hasSwipedUpToOpenComments = true
                }
            }
    }
    
    private var swipeDownToDismiss: some Gesture {
        DragGesture(minimumDistance: GestureConstants.minimumRecognitionDistance)
            .onChanged { value in
                guard (value.translation.height > GestureConstants.minimumVerticalSwipe && abs(value.translation.width) < GestureConstants.maximumHorizontalDeviation) || dismissing else { return }
                dismissing = true
                let translation = value.translation
                heroCoordinator.offset = fromGallery ? translation : CGSize(width: 0, height: translation.height)
                /// Progress For Fading Out the Detail View
                let heightProgress = max(min(translation.height / GestureConstants.dragProgressDivisor, 1), 0)
                heroCoordinator.dragProgress = heightProgress
            }
            .onEnded { value in
                guard dismissing else { return }
                let translation = value.translation
                let velocity = value.velocity
                //let width = translation.width + (velocity.width / GestureConstants.velocityDampening)
                let height = translation.height + (velocity.height / GestureConstants.velocityDampening)

                if height > GestureConstants.dismissThresholdBasic {
                    /// Close View
                    closeImage()
                } else {
                    /// Reset to Origin
                    withAnimation(.easeInOut(duration: 0.2)) {
                        heroCoordinator.offset = .zero
                        heroCoordinator.dragProgress = 0
                    } completion: {
                        dismissing = false
                    }
                }
            }
    }
    
    private func closeImage() {
        if fromGallery {
            tabCoordinator.showTabBar = true
            heroCoordinator.toggleView(show: false) {
                clCoordinator.resetAnimationProperties()
                heroCoordinator.resetAnimationProperties()
                dismissing = false
            }
        } else {
            // Reset coordinator state to prevent stale state on rapid open/close
            heroCoordinator.resetAnimationProperties()
            clCoordinator.resetAnimationProperties()
            dismissing = false
            dismiss()
        }
    }
}

#Preview {
    CollectionDetailView()
        .environment(TabViewCoordinator())
        .environment(CollectionCoordinator(collectionId: ClCollection.MOCK_COLLECTIONS[0].id))
        .environment(HeroCoordinator())
}
