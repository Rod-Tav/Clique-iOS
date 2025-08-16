//
//  PhotoPickerConfiguration.swift
//  Clique
//
//  Configuration and context for photo picker views
//

import SwiftUI
import Photos
import Toasts

/// Configuration for photo picker views
struct PhotoPickerConfiguration {
    let imageManager = PHCachingImageManager()
    var thumbnailSize = CGSize(width: 300, height: 300)
    var columns: [GridItem] = Array(repeating: GridItem(.fixed((UIScreen.width - 4) / 3), spacing: 2), count: 3)
    var isDragSelectionEnabled = true
}

/// Context object passed to photo picker content
@Observable final class PhotoPickerContext {
    var configuration = PhotoPickerConfiguration()
    var thumbnailCache: [PHAsset: UIImage] = [:]
    var isProcessing: Bool = false
    
    // Progress tracking
    var processingProgress: Double = 0.0
    var processedCount: Int = 0
    var totalCount: Int = 0
    
    // Convenience accessors
    var imageManager: PHCachingImageManager { configuration.imageManager }
    var thumbnailSize: CGSize { configuration.thumbnailSize }
    var columns: [GridItem] { configuration.columns }
    var isDragSelectionEnabled: Bool { configuration.isDragSelectionEnabled }
    
    func loadThumbnail(for asset: PHAsset) {
        guard thumbnailCache[asset] == nil else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailCache[asset] = image
                }
            }
        }
    }
    
    func toggleSelection(_ asset: PHAsset, viewModel: CreateViewModel) {
        if viewModel.selectedAssets.contains(asset) {
            viewModel.removeAsset(asset)
        } else {
            viewModel.selectedAssets.insert(asset)
        }
    }
    
    func processSelectedPhotos(
        viewModel: CreateViewModel,
        tabViewCoordinator: TabViewCoordinator,
        presentToast: @escaping (ToastValue) -> Void,
        clearExistingData: Bool
    ) {
        isProcessing = true
        let assetsToProcess = clearExistingData
        ? Array(viewModel.selectedAssets)
        : Array(viewModel.selectedAssets).filter { !viewModel.processedAssets.contains($0) }
        
        // Initialize progress tracking
        totalCount = assetsToProcess.count
        processedCount = 0
        processingProgress = 0.0
        
        Task {
            await PhotoProcessingHelper.processAssets(
                assets: assetsToProcess,
                viewModel: viewModel,
                clearExistingData: clearExistingData,
                onProgress: { processed, total in
                    self.processedCount = processed
                    self.totalCount = total
                    self.processingProgress = total > 0 ? Double(processed) / Double(total) : 0.0
                },
                onError: { error in
                    self.isProcessing = false
                    self.processingProgress = 0.0
                    presentToast(Toasts.photoLoadError(
                        errorCode: (error as NSError).code,
                        errorDomain: (error as NSError).domain
                    ))
                },
                onComplete: {
                    // Immediately complete and navigate
                    self.isProcessing = false
                    self.processingProgress = 0.0
                    self.processedCount = 0
                    self.totalCount = 0
                    
                    if !viewModel.selectedImages.isEmpty {
                        tabViewCoordinator.createNavigationPath.append(CreateFlowDestination.reviewPhotos)
                    }
                }
            )
        }
    }
}
