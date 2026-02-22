//
//  SharedAlbumPickerSheetFunctions.swift
//  Clique
//
//  Logic companion: fetch shared albums, load thumbnails, handle selection.
//

import SwiftUI
import Photos

@available(iOS 26, *)
extension SharedAlbumPickerSheet {

    /// Request photo library access if needed, then fetch shared albums.
    func loadAlbumsIfNeeded() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        await MainActor.run { authorizationStatus = status }

        switch status {
        case .authorized, .limited:
            fetchSharedAlbums()
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                authorizationStatus = newStatus
                if newStatus == .authorized || newStatus == .limited {
                    fetchSharedAlbums()
                } else {
                    isLoading = false
                }
            }
        default:
            await MainActor.run { isLoading = false }
        }
    }

    /// Fetch all iCloud Shared Albums, including empty ones.
    func fetchSharedAlbums() {
        let sharedAlbumsFetch = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumCloudShared,
            options: nil
        )

        var albumList: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []

        sharedAlbumsFetch.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            let title = collection.localizedTitle ?? "Album"
            albumList.append((collection: collection, title: title, count: assets.count, thumbnail: nil))
        }

        albums = albumList
        isLoading = false
        loadAlbumThumbnails()
    }

    /// Load a cover thumbnail for each shared album from its most recent asset.
    func loadAlbumThumbnails() {
        for (index, album) in albums.enumerated() {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1

            let assets = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
            guard let firstAsset = assets.firstObject else { continue }

            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            imageManager.requestImage(
                for: firstAsset,
                targetSize: CGSize(width: 320, height: 320),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image {
                    DispatchQueue.main.async {
                        guard index < self.albums.count else { return }
                        self.albums[index].thumbnail = image
                    }
                }
            }
        }
    }

    /// Associate the selected album with the collection, show toast, and dismiss.
    func selectAlbum(_ album: (collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)) {
        let userId = userStore.currentUserId ?? ""
        associationStore.associate(collectionId: collectionId, album: album.collection, userId: userId)
        presentToast(Toasts.albumLinked)
        dismiss()
    }

    /// Remove the association for this collection, show toast, and dismiss.
    func unlinkAlbum() {
        associationStore.disassociate(collectionId: collectionId)
        presentToast(Toasts.albumUnlinked)
        dismiss()
    }
}
