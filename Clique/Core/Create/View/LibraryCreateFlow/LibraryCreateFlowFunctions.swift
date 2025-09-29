//
//  LibraryCreateFlowFunctions.swift
//  Clique
//
//  Created by Rod Tavangar on 8/2/25.
//

import Foundation

extension LibraryCreateFlow {
    internal func handleClearTap() {
        // Show confirmation for 5+ photos to prevent accidental loss of work
        if totalCount >= 5 {
            showClearConfirmation = true
        } else {
            clearAllSelections()
        }
    }

    internal func clearAllSelections() {
        viewModel.selectedAssets.removeAll()
        viewModel.selectedImages.removeAll()
        viewModel.selectedImagesDates.removeAll()
        viewModel.processedAssets.removeAll()
        viewModel.processedImageData.removeAll()
    }
}
