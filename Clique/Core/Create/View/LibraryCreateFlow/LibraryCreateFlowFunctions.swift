//
//  LibraryCreateFlowFunctions.swift
//  Clique
//
//  Created by Rod Tavangar on 8/2/25.
//

import Foundation

extension LibraryCreateFlow {
    internal func clearAllSelections() {
        viewModel.selectedAssets.removeAll()
        viewModel.selectedImages.removeAll()
        viewModel.selectedImagesDates.removeAll()
        viewModel.processedAssets.removeAll()
        viewModel.processedImageData.removeAll()
    }
}
