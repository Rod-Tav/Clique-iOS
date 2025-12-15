//
//  UserFlicksDetailView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/9/25.
//

import SwiftUI
import Toasts

struct UserFlicksDetailView: View {
    @Environment(\.presentToast) private var presentToast

    @Environment(HeroCoordinator.self) private var heroCoordinator
    @Environment(TabViewCoordinator.self) private var tabCoordinator
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(UserStore.self) private var userStore

    @Bindable var coordinator: UserFlicksDetailCoordinator

    let items: [UserFlickItem]

    // MARK: - State
    @State private var dismissing: Bool = false
    @State private var isZoomed: Bool = false
    @State private var isScrolling: Bool = false
    @State private var likeAnimation: Bool = false

    // MARK: - Show States
    @State private var showCommentSheet: Bool = false
    @State private var showLikedMembers: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showReportCover: Bool = false
    @State private var shareItem: ShareItem?
    @State private var showSharePreparation: Bool = false
    @State private var showCliqueMembers: Bool = false

    // MARK: - Computed
    private var currentItem: UserFlickItem? {
        guard let id = coordinator.selectedImageId else { return nil }
        return items.first { $0.id == id }
    }

    private var selectedImage: CollectionImage? {
        guard let id = coordinator.selectedImageId else { return nil }
        return collectionImageStore.images[id]
    }

    private var currentCollection: ClCollection? {
        guard let collectionId = currentItem?.collectionId else { return nil }
        return collectionStore.collections[collectionId]
    }

    private var currentCliqueMembers: [User]? {
        guard let cliqueId = currentItem?.cliqueId ?? currentCollection?.cliqueId,
              let clique = cliqueStore.cliques[cliqueId] else { return nil }
        return clique.memberIDs?.compactMap { userStore.users[$0] }
    }

    var body: some View {
        ZoomContainer {
            VStack(spacing: 0) {
                topBar
                    .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)

                Spacer()

                imageCarousel
                    .opacity(heroCoordinator.showDetailView ? 1 : 0)

                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    bottomIndicator
                    cliqueInfoSection
                    bottomActionBar
                }
                .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
            }
        }
        .background(backgroundView)
        .commentSheet(imageId: coordinator.selectedImageId, fromCollectionDetail: true, showCommentSheet: $showCommentSheet)
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: closeImage) {
                IconImage(name: "arrow-left", color: .theme.white, size: 24)
            }
            .buttonStyle(.noHighlight)

            // Collection name and date info (tappable to navigate to collection)
            if let collection = currentCollection, let image = selectedImage {
                NavigationLink(value: collection) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(collection.name)
                                .font(.callout.bold())
                                .foregroundStyle(Color.theme.white)

                            if collection.visibility == .priv {
                                IconImage(name: "lock", color: .theme.white, size: 16)
                                    .padding(.leading, 2)
                            }

                            IconImage(name: "chevron-right", color: .theme.white, size: 16)
                        }

                        // Date and author info
                        HStack(spacing: 4) {
                            DateMediaTypeLabel(
                                image: image,
                                dateFormat: .short,
                                fontSize: .caption2,
                                textColor: .theme.shadesWhite95
                            )

                            if let owner = image.owner {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(Color.theme.shadesWhite95)

                                Text("by \(owner.firstname)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.theme.shadesWhite95)
                            }
                        }
                    }
                }
                .noHighlight()
            } else if let image = selectedImage {
                // Fallback when collection is not loaded - show collection name from item
                VStack(alignment: .leading, spacing: 2) {
                    if let collectionName = currentItem?.collectionName {
                        Text(collectionName)
                            .font(.callout.bold())
                            .foregroundStyle(Color.theme.white)
                    }

                    HStack(spacing: 4) {
                        DateMediaTypeLabel(
                            image: image,
                            dateFormat: .short,
                            fontSize: .caption2,
                            textColor: .theme.shadesWhite95
                        )

                        if let owner = image.owner {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(Color.theme.shadesWhite95)

                            Text("by \(owner.firstname)")
                                .font(.caption2)
                                .foregroundStyle(Color.theme.shadesWhite95)
                        }
                    }
                }
            }

            Spacer()

            // Ellipsis menu
            if let image = selectedImage, let collectionId = currentItem?.collectionId {
                Menu {
                    CollectionImageMenuContent(
                        image: image,
                        collectionId: collectionId,
                        showDeleteAlert: $showDeleteAlert,
                        showReportCover: $showReportCover,
                        shareItem: $shareItem,
                        showSharePreparation: $showSharePreparation
                    )
                } label: {
                    EllipsisImage(color: .theme.white, size: 24)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .fullScreenCover(isPresented: $showReportCover) {
            if let imageId = coordinator.selectedImageId {
                ReportView(showReport: $showReportCover, objectId: imageId, reportType: .image)
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Are you sure you want to delete this flick?"),
                message: Text("This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    handleDeleteFlick()
                },
                secondaryButton: .cancel()
            )
        }
        .shareSheet(item: $shareItem)
    }

    // MARK: - Image Carousel

    private var imageCarousel: some View {
        @Bindable var bindableCoord = coordinator

        return ZStack {
            // Hero close animation (only render when dismissing)
            if dismissing, let selectedImage {
                CollectionDetailImageAsyncView(
                    image: selectedImage,
                    quality: .high,
                    isVisible: true
                )
                .contentShape(.rect)
            }

            // Main carousel
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(items, id: \.id) { item in
                        if let image = collectionImageStore.images[item.id] {
                            imageCell(image)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $bindableCoord.detailScrollPosition)
            .scrollDisabled(dismissing)
            .onChange(of: bindableCoord.detailScrollPosition) { oldValue, newValue in
                guard !dismissing else { return }
                if isScrolling {
                    coordinator.selectedImageId = newValue
                } else {
                    withAnimation(.snappy) {
                        coordinator.selectedImageId = newValue
                    }
                }

                // Update hero image for correct close animation
                if let newValue, let urls = collectionImageStore.images[newValue]?.imageUrl {
                    heroCoordinator.imageUrls = urls
                }
            }
            .onChange(of: coordinator.selectedImageId) { oldValue, newValue in
                guard !dismissing, let newValue else { return }

                // Reset zoom when changing images
                if oldValue != newValue {
                    isZoomed = false
                }

                // Sync indicator
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if newValue == coordinator.selectedImageId {
                        scrollCarousel(to: newValue)
                    }
                }
            }
            .infiniteFrame()
            .opacity(dismissing ? 0 : 1)
            .doubleTapToLike(hasLiked: selectedImage?.hasLiked ?? false, likeAnimation: $likeAnimation) {
                handleLikeTapped()
            }
            .overlay {
                IconImage(name: "heart-filled", color: .theme.red, size: 70)
                    .likeAnimation($likeAnimation)
            }
        }
        .background(destinationAnchor)
        .offset(heroCoordinator.offset)
        .compatibleDragGesture(
            minimumDistance: GestureConstants.minimumRecognitionDistance,
            onChanged: handleDragChanged,
            onEnded: handleDragEnded
        )
    }

    private func imageCell(_ image: CollectionImage) -> some View {
        CollectionDetailImageAsyncView(
            image: image,
            quality: .high,
            isVisible: shouldLoadPhoto(imageId: image.id)
        )
        .contentShape(.rect)
        .id(image.id)
        .if(!image.isVideo && !image.isLivePhoto) { view in
            view.pinchZoom(isZoomed: $isZoomed)
        }
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.7)
                .scaleEffect(phase.isIdentity ? 1 : 0.85)
        }
        .swipeUpToOpenCommentsTutorial()
        .compatibleDragGesture(
            minimumDistance: 10,
            onChanged: { translation in
                // Check if the swipe was mostly vertical and upwards
                if translation.height < -20 && abs(translation.width) < 20 {
                    haptics(.light)
                    showCommentSheet = true
                }
            },
            onEnded: { _, _ in }
        )
    }

    private var destinationAnchor: some View {
        Rectangle()
            .fill(.clear)
            .anchorPreference(key: HeroKey.self, value: .bounds) { anchor in
                guard let url = selectedImage?.imageUrl?.highQualityUrl else { return [:] }
                return [url + "DEST": anchor]
            }
            .frameRatio(width: UIScreen.width, ratio: Constants.collectionImageDetailRatio)
    }

    private func shouldLoadPhoto(imageId: String) -> Bool {
        guard !isScrolling else { return false }
        guard let selectedImageId = coordinator.selectedImageId,
              let currentIndex = items.firstIndex(where: { $0.id == selectedImageId }),
              let imageIndex = items.firstIndex(where: { $0.id == imageId }) else {
            return false
        }
        let distance = abs(imageIndex - currentIndex)
        return distance <= 2
    }

    // MARK: - Bottom Indicator

    private var bottomIndicator: some View {
        @Bindable var bindableCoord = coordinator

        let hSpacing: CGFloat = 4
        let centerImageSpacing: CGFloat = 8 - hSpacing
        let centerImageWidth = UIScreen.width / ScaleFactors.collectionCarouselSelectedItem
        let sideImageWidth = (UIScreen.width - centerImageWidth - (hSpacing * 12)) / 8
        let sideImageHeight = sideImageWidth / Constants.collectionCarouselRatio
        let centerImageHeight = centerImageWidth / Constants.collectionCarouselSelectedRatio

        return ScrollView(.horizontal) {
            LazyHStack(spacing: hSpacing) {
                ForEach(items, id: \.id) { item in
                    if let image = collectionImageStore.images[item.id] {
                        let isSelected = image.id == coordinator.selectedImageId
                        thumbnailCell(
                            image,
                            width: (isSelected && !isScrolling) ? centerImageWidth : sideImageWidth,
                            height: (isSelected && !isScrolling) ? centerImageHeight : sideImageHeight
                        )
                        .padding(.horizontal, (isSelected && !isScrolling) ? centerImageSpacing : 0)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .isInteracting($isScrolling)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $bindableCoord.detailIndicatorPosition)
        .scrollIndicators(.hidden)
        .onChange(of: bindableCoord.detailIndicatorPosition) { _, newValue in
            if let newValue {
                coordinator.didDetailIndicatorPageChanged(updatedImageId: newValue)
            }
        }
        .frame(height: centerImageHeight)
        .safeAreaPadding(.horizontal, (UIScreen.width - centerImageWidth - (centerImageSpacing * 2)) / 2)
    }

    private func thumbnailCell(_ image: CollectionImage, width: CGFloat, height: CGFloat) -> some View {
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
        .if(heroCoordinator.showDetailView) { view in
            view.animation(.snappy, value: (image.id == coordinator.selectedImageId && !isScrolling))
        }
        .animation(.snappy, value: !isScrolling)
        .onTapGesture {
            scrollCarousel(to: image.id)
        }
    }

    // MARK: - Clique Info Section

    @ViewBuilder
    private var cliqueInfoSection: some View {
        if let collection = currentCollection, let members = currentCliqueMembers, !members.isEmpty {
            HStack {
                // Collection name with navigation
                NavigationLink(value: collection) {
                    HStack(spacing: 4) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(collection.name)
                                    .font(.callout.bold())
                                    .foregroundStyle(Color.theme.shadesWhite95)

                                if collection.visibility == .priv {
                                    IconImage(name: "lock", color: .theme.shadesWhite95, size: 16)
                                        .padding(.leading, 2)
                                }

                                IconImage(name: "chevron-right", color: .theme.shadesWhite95, size: 16)
                            }
                        }
                        .maxWidth(.leading)
                    }
                    .contentShape(.rect)
                }
                .noHighlight()

                // Clique members
                CliqueCircularMembersView(
                    members: members,
                    memberLimit: 5,
                    type: .medium,
                    forceDark: true
                )
                .onHighPriorityTap {
                    showCliqueMembers.toggle()
                }
                .sheet(isPresented: $showCliqueMembers) {
                    let cliqueId = currentItem?.cliqueId ?? collection.cliqueId
                    CliqueMembersListSheetView(cid: cliqueId, fromFeed: true, userStore, cliqueStore)
                        .presentationDetents([.fraction(0.35), .fraction(0.999)])
                        .bottomSheetModifiers()
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Comment input button
            Button {
                tabCoordinator.focusCommentKeyboard = true
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
                    .offset(x: 32 - 8)
                    .padding(.trailing, 32 - 8)
                }
                .maxWidth(.leading)
            }
            .buttonStyle(.noHighlight)

            if let image = selectedImage {
                // Like button and count
                HStack(spacing: 6) {
                    Button {
                        haptics(.medium)
                        handleLikeTapped()
                    } label: {
                        IconImage(name: "heart-filled", color: image.hasLiked ? .theme.red : .theme.white, size: 28)
                    }

                    Button {
                        showLikedMembers = true
                    } label: {
                        Text(formatNumber(image.numLikes))
                            .font(.footnote.bold())
                            .foregroundStyle(Color.theme.white)
                    }
                }
                .sheet(isPresented: $showLikedMembers) {
                    LikedUsersListView(imageId: image.id, fromCollectionDetail: true, userStore)
                        .presentationDetents([.fraction(0.35), .fraction(0.999)])
                        .bottomSheetModifiers()
                }

                // Comment button and count
                Button {
                    showCommentSheet = true
                } label: {
                    HStack(spacing: 4) {
                        IconImage(name: "comment-filled", color: .theme.white, size: 28)

                        Text(formatNumber(image.numComments))
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.theme.white)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Background

    private var backgroundView: some View {
        Group {
            if let selectedImage {
                CollectionDetailBackgroundAsyncImage(
                    urls: selectedImage.imageUrl,
                    quality: .low,
                    uploadStatus: selectedImage.uploadStatus,
                    itemId: selectedImage.id,
                    isLivePhoto: selectedImage.isLivePhoto,
                    isVideo: selectedImage.isVideo
                )
                .blur(radius: 12.5, opaque: true)
                .overlay(Color.theme.surfacesImageBgDarkOverlay)
                .overlay(.black.opacity(0.2))
            }
        }
        .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
        .background(Color.theme.black.opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0))
    }

    // MARK: - Actions

    private func handleAppear() {
        tabCoordinator.pan = .disabled
        tabCoordinator.showTabBar = false
        coordinator.toggleView(show: true)
        heroCoordinator.toggleView(show: true)
    }

    private func handleDisappear() {
        tabCoordinator.pan = .pan
        dismissing = false
    }

    private func handleDragChanged(_ translation: CGSize) {
        guard !isZoomed else { return }
        guard (translation.height > GestureConstants.minimumVerticalSwipe &&
               abs(translation.width) < GestureConstants.maximumHorizontalDeviation) ||
               dismissing else { return }

        dismissing = true
        heroCoordinator.offset = translation
        let heightProgress = max(min(translation.height / GestureConstants.dragProgressDivisor, 1), 0)
        heroCoordinator.dragProgress = heightProgress
    }

    private func handleDragEnded(_ translation: CGSize, _ velocity: CGSize) {
        guard dismissing else { return }

        let height = translation.height + (velocity.height / GestureConstants.velocityDampening)

        if height > GestureConstants.dismissThresholdWithVelocity {
            closeImage()
        } else {
            heroCoordinator.offset = .zero
            heroCoordinator.dragProgress = 0
            dismissing = false
        }
    }

    private func scrollCarousel(to id: String) {
        coordinator.detailScrollPosition = id
        coordinator.didDetailPageChanged(updatedImageId: id)

        if let urls = collectionImageStore.images[id]?.imageUrl {
            heroCoordinator.imageUrls = urls
        }
    }

    private func closeImage() {
        tabCoordinator.showTabBar = true
        heroCoordinator.toggleView(show: false) {
            coordinator.resetAnimationProperties()
            heroCoordinator.resetAnimationProperties()
            dismissing = false
        }
    }

    private func handleLikeTapped() {
        guard let image = selectedImage else { return }
        do {
            try handleCollectionImageLikeTapped(image: image, collectionImageStore)
        } catch {
            presentToast(Toasts.somethingWentWrong)
        }
    }

    private func handleDeleteFlick() {
        guard let imageId = coordinator.selectedImageId,
              let collectionId = currentItem?.collectionId else { return }

        Task {
            await CollectionImageSaveHelpers.deleteCollectionItem(
                imageId: imageId,
                collectionId: collectionId,
                collectionStore: collectionStore,
                collectionImageStore: collectionImageStore,
                presentToast: { toast in presentToast(toast) },
                onSuccess: {
                    // Close the detail view after successful deletion
                    closeImage()
                }
            )
        }
    }
}
