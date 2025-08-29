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
    
    /// Dynamic thumbnail size based on actual grid cell size
    var thumbnailSize: CGSize {
        // Calculate actual cell size from grid layout
        let spacing: CGFloat = 2
        let totalSpacing = spacing * 2
        let cellSize = (UIScreen.width - totalSpacing) / 3
        
        // Use 2x scale for Retina displays for sharper thumbnails
        let scale = UIScreen.main.scale
        let size = cellSize * min(scale, 2.0) // Cap at 2x to balance quality and memory
        
        return CGSize(width: size, height: size)
    }
    
    /// Small thumbnail size for carousel and other compact views
    var carouselThumbnailSize = CGSize(width: 120, height: 120)
    
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
    var carouselThumbnailSize: CGSize { configuration.carouselThumbnailSize }
    var columns: [GridItem] { configuration.columns }
    var isDragSelectionEnabled: Bool { configuration.isDragSelectionEnabled }
    
    /// Load thumbnail for grid display (uses dynamic sizing)
    func loadThumbnail(for asset: PHAsset) {
        guard thumbnailCache[asset] == nil else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast
        
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
    
    /// Load smaller thumbnail for carousel display
    func loadCarouselThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast
        
        imageManager.requestImage(
            for: asset,
            targetSize: carouselThumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
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
