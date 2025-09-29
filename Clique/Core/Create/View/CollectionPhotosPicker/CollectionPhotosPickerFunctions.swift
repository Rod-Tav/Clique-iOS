//
//  CollectionPhotosPickerFunctions.swift
//  Clique
//
//  Created by Rod Tavangar on 8/2/25.
//

import Photos
import UIKit

extension CollectionPhotosPicker {
    /// Photo Library Access
    internal func checkPhotoLibraryAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        
        switch status {
        case .authorized, .limited:
            loadAlbums()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    self.authorizationStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self.loadAlbums()
                    }
                }
            }
        default:
            break
        }
    }
    
    /// Album Management
    internal func loadAlbums() {
        var sharedList: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []
        var otherList: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []
        
        // All Photos
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // Shared albums (this is critical for the fix)
        let sharedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
        sharedAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            if assets.count > 0 {
                let title = collection.localizedTitle ?? "Album"
                sharedList.append((collection: collection, title: title, count: assets.count, thumbnail: nil))
            }
        }
        
        // User albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            if assets.count > 0 {
                otherList.append((collection: collection, title: collection.localizedTitle ?? "Album", count: assets.count, thumbnail: nil))
            }
        }
        
        // Smart albums (Recents, Favorites, etc.)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smartAlbums.enumerateObjects { collection, _, _ in
            // Only include specific smart albums
            if collection.assetCollectionSubtype == .smartAlbumUserLibrary ||
                collection.assetCollectionSubtype == .smartAlbumRecentlyAdded ||
                collection.assetCollectionSubtype == .smartAlbumFavorites {
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    otherList.append((collection: collection, title: collection.localizedTitle ?? "Album", count: assets.count, thumbnail: nil))
                }
            }
        }
        
        DispatchQueue.main.async {
            self.sharedAlbums = sharedList
            self.otherAlbums = otherList
            // Load thumbnails for albums
            self.loadAlbumThumbnails()
            // Load all photos by default
            self.loadPhotosFromAllPhotos()
        }
    }
    
    internal func loadAlbumThumbnails() {
        // Load thumbnails for shared albums
        for (index, album) in sharedAlbums.enumerated() {
            loadAlbumThumbnail(for: album.collection) { thumbnail in
                DispatchQueue.main.async {
                    self.sharedAlbums[index].thumbnail = thumbnail
                }
            }
        }
        
        // Load thumbnails for other albums
        for (index, album) in otherAlbums.enumerated() {
            loadAlbumThumbnail(for: album.collection) { thumbnail in
                DispatchQueue.main.async {
                    self.otherAlbums[index].thumbnail = thumbnail
                }
            }
        }
    }
    
    internal func loadAlbumThumbnail(for collection: PHAssetCollection, completion: @escaping (UIImage?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        
        guard let firstAsset = assets.firstObject else {
            completion(nil)
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        
        context.imageManager.requestImage(
            for: firstAsset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    internal func loadPhotosFromAllPhotos() {
        DispatchQueue.main.async {
            self.isLoadingPhotos = true
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        DispatchQueue.main.async {
            self.flicksAssets = assets
            self.isLoadingPhotos = false
        }
    }
    
    /// Clear All Selections
    internal func clearAllSelections() {
        viewModel.clearAllSelections()
    }

    internal func toggleSelection(_ asset: PHAsset) {
        context.toggleSelection(asset, viewModel: viewModel)
    }

    internal func loadThumbnail(for asset: PHAsset) {
        context.loadThumbnail(for: asset)
    }
}
