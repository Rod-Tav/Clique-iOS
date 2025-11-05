//
//  AlbumPhotosViewFunctions.swift
//  Clique
//
//  Created by Rod Tavangar on 8/2/25.
//

import Foundation
import Photos
import UIKit

extension AlbumPhotosView {
    internal func loadPhotosFromAlbum() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        albumAssets = assets
    }
    
    internal func loadThumbnail(for asset: PHAsset) {
        context.loadThumbnail(for: asset)
    }
    
    internal func toggleSelection(_ asset: PHAsset) {
        context.toggleSelection(asset, viewModel: viewModel)
    }

    internal func handleClearTap() {
        // Show confirmation for 5+ photos to prevent accidental loss of work
        if viewModel.selectedAssets.count >= 5 {
            showClearConfirmation = true
        } else {
            clearAllSelections()
        }
    }

    internal func clearAllSelections() {
        viewModel.clearAllSelections()
    }

    internal func selectAllPhotos() {
        albumAssets.forEach { asset in
            if !viewModel.selectedAssets.contains(asset) {
                viewModel.selectedAssets.insert(asset)
            }
        }
    }
    
    internal func deselectAllPhotos() {
        albumAssets.forEach { asset in
            viewModel.removeAsset(asset)
        }
    }
    
}
