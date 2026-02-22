//
//  SharedLibraryGridView.swift
//  Clique
//
//  Library tab: flat grid of all photos from iCloud Shared Albums (deduplicated).
//

import SwiftUI
import Photos

@available(iOS 26, *)
struct SharedLibraryGridView: View {
    @Environment(SharedAlbumsData.self) var sharedData

    @State var coordinator = SharedAlbumCoordinator()
    @State var heroCoordinator = HeroCoordinator()
    @State var showNavBar = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Library")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                gridContent
            }
        }
        .disabled(!coordinator.canInteract)
        .if(!coordinator.isInDetailView) { view in
            view.trackScrollWithToolbar(title: "Shared Album Library", showNavBar: $showNavBar)
        }
        .onScrollGeometryChange(for: PhotosScrollInfo.self) { geo in
            PhotosScrollInfo(
                offsetY: geo.contentOffset.y + geo.contentInsets.top,
                containerHeight: geo.containerSize.height
            )
        } action: { (_: PhotosScrollInfo, info: PhotosScrollInfo) in
            updatePrefetchRange(scrollOffset: info.offsetY, containerHeight: info.containerHeight)
        }
        .heroOverlay {
            SharedAlbumPhotoDetailView(assets: sharedData.allSharedAssets)
                .environment(coordinator)
        }
        .environment(heroCoordinator)
        .onChange(of: heroCoordinator.animateView) { _, newValue in
            if !newValue {
                coordinator.isInDetailView = false
            }
        }
        .onDisappear {
            sharedData.resetCaching()
        }
        .task {
            await checkPhotoAuthorization()
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        if sharedData.isLoadingPhotos {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<30, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .shimmer()
                }
            }
        } else if sharedData.allSharedAssets.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(sharedData.allSharedAssets, id: \.localIdentifier) { asset in
                    TappablePhotosGridCell(
                        thumbnail: sharedData.thumbnailCache[asset],
                        identifier: asset.localIdentifier
                    ) {
                        coordinator.selectedImageId = asset.localIdentifier
                        coordinator.isInDetailView = true
                    }
                    .id(asset.localIdentifier)
                    .task {
                        loadThumbnail(for: asset)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle)
                .foregroundStyle(Color.theme.textSecondary)

            Text("No shared album photos found.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}
