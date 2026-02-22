//
//  SharedAlbumDetailView.swift
//  Clique
//
//  Drill-in photo grid for a single shared album.
//

import SwiftUI
import Photos

@available(iOS 26, *)
struct SharedAlbumDetailView: View {
    let assetCollection: PHAssetCollection
    let title: String

    @Environment(SharedAlbumsData.self) var sharedData
    @State var assets: [PHAsset] = []
    @State var isLoading: Bool = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            gridContent
        }
        .navigationTitle(title)
        .task {
            fetchAlbumPhotos()
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        if isLoading {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .shimmer()
                }
            }
        } else if assets.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    PhotosGridCell(thumbnail: sharedData.thumbnailCache[asset])
                        .task {
                            loadThumbnail(for: asset)
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(Color.theme.textSecondary)

            Text("No photos in this album.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Logic

    private func fetchAlbumPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }

        assets = fetched
        isLoading = false
    }

    private func loadThumbnail(for asset: PHAsset) {
        guard sharedData.thumbnailCache[asset] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        sharedData.imageManager.requestImage(
            for: asset,
            targetSize: sharedData.thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.sharedData.thumbnailCache[asset] = image
                }
            }
        }
    }
}
