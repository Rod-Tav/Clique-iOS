//
//  SelectedPhotosViewFunctions.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import Foundation
import Photos

extension SelectedPhotosView {
    internal func removeCurrentPhoto() {
        guard !selectedAssetsArray.isEmpty && currentIndex < selectedAssetsArray.count else { return }
        
        let assetToRemove = selectedAssetsArray[currentIndex]
        removePhoto(assetToRemove)
    }
    
    internal func removePhoto(_ asset: PHAsset) {
        guard let index = selectedAssetsArray.firstIndex(of: asset) else { return }
        
        viewModel.removeAsset(asset)
        
        // Clean up zoom states
        zoomScales.removeValue(forKey: asset)
        dragOffsets.removeValue(forKey: asset)
        
        // Adjust current index if needed
        if selectedAssetsArray.isEmpty {
            dismiss()
        } else if index >= selectedAssetsArray.count {
            // If we removed the last item, go to the new last item
            currentIndex = max(0, selectedAssetsArray.count - 1)
            scrollPosition = selectedAssetsArray[currentIndex]
        } else {
            // Stay at the same index (next photo slides in)
            currentIndex = min(index, selectedAssetsArray.count - 1)
            if !selectedAssetsArray.isEmpty {
                scrollPosition = selectedAssetsArray[currentIndex]
            }
        }
    }
}