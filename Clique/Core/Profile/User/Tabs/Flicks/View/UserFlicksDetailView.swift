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
    @Environment(UserStore.self) private var userStore

    @Bindable var coordinator: UserFlicksDetailCoordinator

    let imageIds: [String]

    // MARK: - State
    @State private var dismissing: Bool = false
    @State private var isZoomed: Bool = false
    @State private var isScrolling: Bool = false
    @State private var likeAnimation: Bool = false

    // MARK: - Computed
    private var selectedImage: CollectionImage? {
        guard let id = coordinator.selectedImageId else { return nil }
        return collectionImageStore.images[id]
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

                VStack(spacing: 32) {
                    bottomIndicator
                    bottomActionBar
                }
                .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
            }
        }
        .background(backgroundView)
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: closeImage) {
                IconImage(name: "arrow-left", color: .theme.white, size: 24)
            }
            .buttonStyle(.noHighlight)

            Spacer()

            // Date/time header
            if let image = selectedImage {
                VStack(spacing: 2) {
                    DateMediaTypeLabel(
                        image: image,
                        dateFormat: .full,
                        fontSize: .caption,
                        textColor: .theme.white
                    )
                }
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
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
                    ForEach(imageIds, id: \.self) { imageId in
                        if let image = collectionImageStore.images[imageId] {
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
              let currentIndex = imageIds.firstIndex(of: selectedImageId),
              let imageIndex = imageIds.firstIndex(of: imageId) else {
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
                ForEach(imageIds, id: \.self) { imageId in
                    if let image = collectionImageStore.images[imageId] {
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

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            if let image = selectedImage {
                HStack(spacing: 4) {
                    Button {
                        haptics(.medium)
                        handleLikeTapped()
                    } label: {
                        IconImage(
                            name: "heart-filled",
                            color: image.hasLiked ? .theme.red : .theme.white,
                            size: 20
                        )
                    }

                    Text(formatNumber(image.numLikes))
                        .font(.footnote.bold())
                        .foregroundStyle(Color.theme.white)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .maxWidth()
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
}
