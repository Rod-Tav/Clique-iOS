//
//  PhotoDataSource.swift
//  Clique
//
//  Protocol and implementations for providing photos from different sources
//  (iCloud shared albums, Clique backend collections).
//

import Foundation
import Observation
import Photos
import UIKit

// MARK: - Protocol

/// Protocol for providing photos from different sources (iCloud, Clique backend).
protocol PhotoDataSource: AnyObject, Observable {
    /// Ordered list of photo IDs currently loaded.
    var photoIds: [String] { get }
    /// Returns the displayable photo for a given ID, or nil if not found.
    func displayablePhoto(for id: String) -> (any DisplayablePhoto)?
    /// Whether all pages have been loaded.
    var isFullyLoaded: Bool { get }
    /// Load the initial page of photos.
    func loadInitial() async
    /// Load the next page of photos.
    func loadMore() async
}

// MARK: - Shared Album Data Source (iCloud PHAssets)

/// Data source backed by a shared iCloud album's PHAssets.
///
/// All assets are loaded at once via PhotoKit, so pagination is a no-op.
@available(iOS 26, *)
@Observable
class SharedAlbumPhotoDataSource: PhotoDataSource {
    var photoIds: [String] = []
    var isFullyLoaded: Bool = true

    private let sharedAlbumsData: SharedAlbumsData
    private let assets: [PHAsset]
    private var assetLookup: [String: PHAsset] = [:]

    init(sharedAlbumsData: SharedAlbumsData, assets: [PHAsset]) {
        self.sharedAlbumsData = sharedAlbumsData
        self.assets = assets
        self.assetLookup = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
        self.photoIds = assets.map { $0.localIdentifier }
    }

    func displayablePhoto(for id: String) -> (any DisplayablePhoto)? {
        guard let asset = assetLookup[id] else { return nil }
        let thumbnail = sharedAlbumsData.thumbnailCache[asset]
        return SharedAlbumPhoto(asset: asset, thumbnail: thumbnail)
    }

    func loadInitial() async { }
    func loadMore() async { }
}

// MARK: - Clique Backend Data Source (CollectionImages)

/// Data source backed by Clique backend collection images with pagination.
///
/// Delegates to the existing `CollectionImagesPaginationViewModel` and
/// `CollectionImageStore` for fetching and caching.
@Observable @MainActor
class CliquePhotoDataSource: PhotoDataSource {
    var photoIds: [String] = []
    var isFullyLoaded: Bool = false

    private let paginationViewModel: CollectionImagesPaginationViewModel
    private let collectionImageStore: CollectionImageStore

    init(paginationViewModel: CollectionImagesPaginationViewModel, collectionImageStore: CollectionImageStore) {
        self.paginationViewModel = paginationViewModel
        self.collectionImageStore = collectionImageStore
    }

    func displayablePhoto(for id: String) -> (any DisplayablePhoto)? {
        return collectionImageStore.images[id]
    }

    func loadInitial() async {
        // Reset pagination and fetch first page
        paginationViewModel.page = 0
        paginationViewModel.done = false
        paginationViewModel.items = []
        // The actual fetch is driven by the pagination helper in the view layer.
        // This stub exists so the protocol is satisfied; views using CliquePhotoDataSource
        // should continue to use PaginationHelper.updateItems for full integration.
        photoIds = paginationViewModel.items
        isFullyLoaded = paginationViewModel.done
    }

    func loadMore() async {
        // Sync state from the pagination VM after the view layer triggers a load.
        photoIds = paginationViewModel.items
        isFullyLoaded = paginationViewModel.done
    }

    /// Call after the view layer's pagination helper completes a fetch to sync IDs.
    func syncFromPagination() {
        photoIds = paginationViewModel.items
        isFullyLoaded = paginationViewModel.done
    }
}
