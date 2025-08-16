//
//  PhotoProcessingHelper.swift
//  Clique
//
//  Created by Assistant on 8/2/25.
//

import Foundation
import Photos
import UIKit
import SwiftUI

struct PhotoProcessingHelper {
    /// Processes selected photos for upload by preparing photo data and image variants
    static func processSelectedPhotosForUpload(viewModel: CreateViewModel) async {
        // Clear any existing processed data
        viewModel.photoDatePairs.removeAll()
        viewModel.preparedImageVariants.removeAll()
        
        // Capture data before entering task group to avoid data races
        let imagesToProcess = viewModel.selectedImages
        let datesToProcess = viewModel.selectedImagesDates
        
        // Define result type for clarity
        typealias ProcessResult = (index: Int, photoData: Components.Schemas.PhotoDatePair?, variants: (high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)?)
        
        await withTaskGroup(of: ProcessResult.self) { group in
            // Add all processing tasks
            for (index, image) in imagesToProcess.enumerated() {
                group.addTask {
                    let date = index < datesToProcess.count ? datesToProcess[index] : Date()
                    
                    if let (photoData, variants) = prepareUIImage(image) {
                        let photoPair = Components.Schemas.PhotoDatePair(
                            photo: photoData,
                            dateCreated: convertFromDate(date)
                        )
                        return (index, photoPair, (high: variants.high, med: variants.medium, low: variants.low))
                    }
                    return (index, nil, nil)
                }
            }
            
            // Collect all results - this implicitly waits for all tasks
            var results: [ProcessResult] = []
            for await result in group {
                results.append(result)
            }
            // At this point, all tasks are complete
            
            // Sort by index to maintain original order
            results.sort { $0.index < $1.index }
            
            // Append to viewModel in order
            for result in results {
                if let photoData = result.photoData, let variants = result.variants {
                    viewModel.photoDatePairs.append(photoData)
                    viewModel.preparedImageVariants.append(variants)
                }
            }
        }
    }
    
    /// Loads image data from a PHAsset with high quality settings
    static func loadImageFromAsset(_ asset: PHAsset) async throws -> (Data, UIImage) {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat // Ensure high quality
            options.isNetworkAccessAllowed = true // Important for iCloud photos
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, dataUTI, orientation, info in
                if let data = data, let image = UIImage(data: data) {
                    continuation.resume(returning: (data, image))
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "PhotoLoading",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"]
                    ))
                }
            }
        }
    }
    
    /// Processes an array of PHAssets, loading their images and updating the view model
    static func processAssets(
        assets: [PHAsset],
        viewModel: CreateViewModel,
        clearExistingData: Bool = false,
        onProgress: @MainActor @escaping (Int, Int) -> Void = { _, _ in },
        onError: @MainActor @escaping (Error) -> Void,
        onComplete: @MainActor @escaping () -> Void
    ) async {
        // Clear existing data if requested
        if clearExistingData {
            await MainActor.run {
                viewModel.selectedImages.removeAll()
                viewModel.selectedImagesDates.removeAll()
                viewModel.processedAssets.removeAll()
                viewModel.processedImageData.removeAll()
            }
        }
        
        // Define result type for clarity
        typealias ProcessedAssetResult = (index: Int, asset: PHAsset, image: UIImage?, date: Date, error: Error?)
        
        // Process assets concurrently with controlled parallelism
        await withTaskGroup(of: ProcessedAssetResult.self) { group in
            // Add all tasks at once - TaskGroup handles concurrency automatically
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    do {
                        // Load image data using PHImageManager
                        let (_, image) = try await loadImageFromAsset(asset)
                        return (index, asset, image, asset.creationDate ?? Date(), nil)
                    } catch {
                        print("Failed to load asset at index \(index): \(error)")
                        return (index, asset, nil, asset.creationDate ?? Date(), error)
                    }
                }
            }
            
            // Collect all results and report progress
            var results: [ProcessedAssetResult] = []
            let totalAssets = assets.count
            var processedCount = 0
            
            for await result in group {
                results.append(result)
                processedCount += 1
                
                // Report progress after each asset completes
                let currentCount = processedCount
                await MainActor.run {
                    onProgress(currentCount, totalAssets)
                }
            }
            
            // Sort results by original index to maintain order
            results.sort { $0.index < $1.index }
            
            // Process results and update view model
            let sortedResults = results // Create a copy to avoid concurrency issues
            
            // Separate successful results from errors
            let successfulAssets = sortedResults.compactMap { result -> (asset: PHAsset, image: UIImage, date: Date)? in
                guard let image = result.image else { return nil }
                return (asset: result.asset, image: image, date: result.date)
            }
            
            let errors = sortedResults.compactMap { $0.error }
            
            // Update view model with batch operation
            await MainActor.run {
                // Batch add all successful assets at once
                if !successfulAssets.isEmpty {
                    viewModel.addProcessedAssets(successfulAssets)
                }
                
                // Handle errors
                for error in errors {
                    onError(error)
                }
                
                // Call completion handler
                onComplete()
            }
        }
    }
}
