//
//  SharedAlbumsListViewFunctions.swift
//  Clique
//
//  Logic companion: fetch shared albums and load cover thumbnails.
//

import SwiftUI
import Photos

@available(iOS 26, *)
extension SharedAlbumsListView {
    /// Kick off Cloud Clique metadata fetch.
    func loadCloudCliques() {
        Task {
            await cloudCliquesStore.loadCliques()
        }
    }

    /// Load shared albums if not already loaded.
    func loadAlbumsIfNeeded() async {
        loadCloudCliques()
        guard sharedData.isLoadingAlbums else { return }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        sharedData.authorizationStatus = status

        switch status {
        case .authorized, .limited:
            fetchSharedAlbums()
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                sharedData.authorizationStatus = newStatus
                if newStatus == .authorized || newStatus == .limited {
                    fetchSharedAlbums()
                } else {
                    sharedData.isLoadingAlbums = false
                }
            }
        default:
            await MainActor.run {
                sharedData.isLoadingAlbums = false
            }
        }
    }

    /// Fetch all iCloud Shared Albums and store them, then load cover thumbnails.
    func fetchSharedAlbums() {
        let sharedAlbumsFetch = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumCloudShared,
            options: nil
        )

        var albumList: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []

        sharedAlbumsFetch.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            if assets.count > 0 {
                let title = collection.localizedTitle ?? "Album"
                albumList.append((collection: collection, title: title, count: assets.count, thumbnail: nil))
            }
        }

        sharedData.sharedAlbums = albumList
        sharedData.isLoadingAlbums = false
        loadAlbumThumbnails()
        detectAlbumActivity()
    }

    /// Compare current album photo counts against stored snapshots to detect new photos.
    func detectAlbumActivity() {
        let currentAlbums = sharedData.sharedAlbums.map {
            (localIdentifier: $0.collection.localIdentifier, title: $0.title, count: $0.count)
        }
        activityChanges = activityStore.detectChanges(currentAlbums: currentAlbums)
    }

    /// Load a cover thumbnail for each shared album from its first asset.
    func loadAlbumThumbnails() {
        for (index, album) in sharedData.sharedAlbums.enumerated() {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1

            let assets = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)

            guard let firstAsset = assets.firstObject else { continue }

            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true // shared albums need iCloud access
            options.resizeMode = .fast

            sharedData.imageManager.requestImage(
                for: firstAsset,
                targetSize: sharedData.albumThumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image {
                    DispatchQueue.main.async {
                        guard index < self.sharedData.sharedAlbums.count else { return }
                        self.sharedData.sharedAlbums[index].thumbnail = image
                    }
                }
            }
        }
    }
}
