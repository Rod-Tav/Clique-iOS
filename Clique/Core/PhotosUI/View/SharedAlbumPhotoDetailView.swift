//
//  SharedAlbumPhotoDetailView.swift
//  Clique
//
//  Full-screen photo detail carousel for shared album / library PHAssets.
//

import SwiftUI
import Photos

@available(iOS 26, *)
struct SharedAlbumPhotoDetailView: View {
    @Environment(SharedAlbumCoordinator.self) var coordinator
    @Environment(HeroCoordinator.self) var heroCoordinator
    @Environment(SharedAlbumsData.self) var sharedData

    let assets: [PHAsset]

    @State private var fullImages: [String: UIImage] = [:]
    @State private var dismissing: Bool = false
    @State private var isZoomed: Bool = false
    @State private var isScrolling: Bool = false

    private var selectedAsset: PHAsset? {
        guard let id = coordinator.selectedImageId else { return nil }
        return assets.first { $0.localIdentifier == id }
    }

    // MARK: - Body

    var body: some View {
        ZoomContainer {
            VStack(spacing: 0) {
                topBar
                    .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)

                Spacer()

                imageDetail
                    .opacity(heroCoordinator.showDetailView ? 1 : 0)

                Spacer(minLength: 0)

                bottomIndicator
                    .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
            }
        }
        .onAppear {
            coordinator.toggleView(show: true)
            heroCoordinator.toggleView(show: true)
        }
        .background {
            if selectedAsset != nil {
                Color.black
                    .opacity(heroCoordinator.animateView ? 1 - heroCoordinator.dragProgress : 0)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    closeImage()
                } label: {
                    IconImage(name: "arrow-left", color: .theme.white, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: {
                if let asset = selectedAsset, let date = asset.creationDate {
                    Text(date, style: .date)
                        .font(.callout.bold())
                        .foregroundStyle(Color.theme.white)
                }
            },
            trailingIcon: {
                Color.clear.frame(width: 24, height: 24)
            }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Image Detail Carousel

    private var imageDetail: some View {
        ZStack {
            @Bindable var bindableCoord = coordinator

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        assetDetailCell(asset)
                            .id(asset.localIdentifier)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $bindableCoord.detailScrollPosition)
            .scrollDisabled(dismissing || isZoomed)
            .onChange(of: bindableCoord.detailScrollPosition) { _, newValue in
                guard !dismissing, let newValue else { return }
                isZoomed = false
                coordinator.selectedImageId = newValue
                withAnimation {
                    coordinator.detailIndicatorPosition = newValue
                }
                // Update hero identifier for correct source cell hiding
                heroCoordinator.heroIdentifier = newValue
                if let matched = assets.first(where: { $0.localIdentifier == newValue }) {
                    heroCoordinator.heroImage = sharedData.thumbnailCache[matched]
                }
            }
            .onChange(of: coordinator.selectedImageId) { oldValue, newValue in
                guard !dismissing, let newValue else { return }
                if oldValue != newValue { isZoomed = false }
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if newValue == coordinator.selectedImageId {
                        scrollCarousel(to: newValue)
                    }
                }
            }
        }
        .background {
            Rectangle()
                .fill(.clear)
                .anchorPreference(key: HeroKey.self, value: .bounds) { anchor in
                    guard let id = coordinator.selectedImageId else { return [:] }
                    return [id + "DEST": anchor]
                }
        }
        .offset(heroCoordinator.offset)
        .compatibleDragGesture(
            minimumDistance: GestureConstants.minimumRecognitionDistance,
            onChanged: { translation in
                guard !isZoomed else { return }
                guard (translation.height > GestureConstants.minimumVerticalSwipe && abs(translation.width) < GestureConstants.maximumHorizontalDeviation) || dismissing else { return }
                dismissing = true
                heroCoordinator.offset = translation
                let heightProgress = max(min(translation.height / GestureConstants.dragProgressDivisor, 1), 0)
                heroCoordinator.dragProgress = heightProgress
            },
            onEnded: { translation, velocity in
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
        )
    }

    @ViewBuilder
    private func assetDetailCell(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier

        Group {
            if let fullImage = fullImages[id] {
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let thumb = sharedData.thumbnailCache[asset] {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .pinchZoom(isZoomed: $isZoomed)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task {
            loadFullResolution(for: asset)
        }
    }

    // MARK: - Bottom Indicator

    private var bottomIndicator: some View {
        let hSpacing: CGFloat = 4
        let centerImageSpacing: CGFloat = 8 - hSpacing
        let centerWidth = UIScreen.width / ScaleFactors.collectionCarouselSelectedItem
        let sideWidth = (UIScreen.width - centerWidth - (hSpacing * 12)) / 8
        let sideHeight = sideWidth / Constants.collectionCarouselRatio
        let centerHeight = centerWidth / Constants.collectionCarouselSelectedRatio

        return bottomCarouselList(
            hSpacing: hSpacing,
            centerImageSpacing: centerImageSpacing,
            centerWidth: centerWidth,
            sideWidth: sideWidth,
            sideHeight: sideHeight,
            centerHeight: centerHeight
        )
        .frame(height: centerHeight)
        .safeAreaPadding(.horizontal, (UIScreen.width - centerWidth - (centerImageSpacing * 2)) / 2)
        .padding(.bottom, 16)
        .onChange(of: coordinator.detailIndicatorPosition) { _, newValue in
            if let newValue {
                coordinator.didDetailIndicatorPageChanged(updatedImageId: newValue)
                heroCoordinator.heroIdentifier = newValue
                if let matched = assets.first(where: { $0.localIdentifier == newValue }) {
                    heroCoordinator.heroImage = sharedData.thumbnailCache[matched]
                }
            }
        }
    }

    private func bottomCarouselList(
        hSpacing: CGFloat,
        centerImageSpacing: CGFloat,
        centerWidth: CGFloat,
        sideWidth: CGFloat,
        sideHeight: CGFloat,
        centerHeight: CGFloat
    ) -> some View {
        @Bindable var bindableCoord = coordinator

        return ScrollView(.horizontal) {
            LazyHStack(spacing: hSpacing) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    let isSelected = asset.localIdentifier == coordinator.selectedImageId && !isScrolling

                    thumbnailCell(asset, width: isSelected ? centerWidth : sideWidth, height: isSelected ? centerHeight : sideHeight)
                        .padding(.horizontal, isSelected ? centerImageSpacing : 0)
                        .animation(.snappy, value: isSelected)
                        .onTapGesture {
                            scrollCarousel(to: asset.localIdentifier)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .isInteracting($isScrolling)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $bindableCoord.detailIndicatorPosition)
    }

    @ViewBuilder
    private func thumbnailCell(_ asset: PHAsset, width: CGFloat, height: CGFloat) -> some View {
        if let thumb = sharedData.thumbnailCache[asset] {
            Image(uiImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .roundCorners(4)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: width, height: height)
                .roundCorners(4)
        }
    }

    // MARK: - Helpers

    private func closeImage() {
        heroCoordinator.toggleView(show: false) {
            coordinator.resetAnimationProperties()
            heroCoordinator.resetAnimationProperties()
            dismissing = false
        }
    }

    private func scrollCarousel(to id: String) {
        coordinator.detailScrollPosition = id
        coordinator.didDetailPageChanged(updatedImageId: id)
        heroCoordinator.heroIdentifier = id
        if let matched = assets.first(where: { $0.localIdentifier == id }) {
            heroCoordinator.heroImage = sharedData.thumbnailCache[matched]
        }
    }

    private func loadFullResolution(for asset: PHAsset) {
        let id = asset.localIdentifier
        guard fullImages[id] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .none

        let targetSize = CGSize(
            width: UIScreen.width * UIScreen.main.scale,
            height: UIScreen.height * UIScreen.main.scale
        )

        sharedData.imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.fullImages[id] = image
                }
            }
        }
    }
}
