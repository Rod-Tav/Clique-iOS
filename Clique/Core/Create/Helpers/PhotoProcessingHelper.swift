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
    /// Processes selected photos for upload by preparing photo data and image variants.
    /// For Live Photos, extracts both still image and video components.
    static func processSelectedPhotosForUpload(viewModel: CreateViewModel) async {
        // Clear any existing processed data
        viewModel.photoDatePairs.removeAll()
        viewModel.preparedImageVariants.removeAll()

        // Capture data before entering task group to avoid data races
        let imagesToProcess = viewModel.selectedImages
        let datesToProcess = viewModel.selectedImagesDates
        let assetsToProcess = Array(viewModel.processedAssets)
        let livePhotoIdentifiers = viewModel.livePhotoAssets

        // Define result type for clarity
        typealias ProcessResult = (
            index: Int,
            photoData: Components.Schemas.PhotoVideoDate?,
            variants: (high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)?,
            videoData: Data?
        )

        await withTaskGroup(of: ProcessResult.self) { group in
            // Add all processing tasks
            for (index, image) in imagesToProcess.enumerated() {
                group.addTask {
                    let date = index < datesToProcess.count ? datesToProcess[index] : Date()

                    // Find the corresponding PHAsset for this image
                    let matchingAsset = assetsToProcess.first { asset in
                        guard let imageData = viewModel.processedImageData[asset.localIdentifier] else { return false }
                        return imageData.image === image
                    }

                    // Check if this is a Live Photo
                    let isLivePhoto = matchingAsset.map { livePhotoIdentifiers.contains($0.localIdentifier) } ?? false

                    // Extract video component if this is a Live Photo
                    var videoData: Data?
                    if isLivePhoto, let asset = matchingAsset {
                        do {
                            let components = try await LivePhotoHelper.extractLivePhotoComponents(from: asset)
                            videoData = components.videoData
                            print("✅ Extracted Live Photo video component (\(components.videoMetadata.fileSize) bytes)")
                        } catch {
                            print("⚠️ Failed to extract Live Photo video: \(error.localizedDescription)")
                            // Continue with still image only
                        }
                    }

                    if let (photoData, variants) = prepareUIImage(image) {
                        // Prepare video data if available (Live Photos only)
                        var videoDataNoPath: Components.Schemas.VideoDataNoPath?
                        if let videoData = videoData {
                            // Backend expects video metadata (not data - that's uploaded separately)
                            videoDataNoPath = Components.Schemas.VideoDataNoPath(
                                baseVideo: Components.Schemas.UploadVideoParams(
                                    contentType: "video/quicktime",
                                    contentLength: Int64(videoData.count)
                                )
                            )
                        }

                        let photoPair = Components.Schemas.PhotoVideoDate(
                            photo: photoData,
                            video: videoDataNoPath,
                            mediaType: isLivePhoto ? .LIVE : .PHOTO,
                            dateCreated: convertFromDate(date)
                        )
                        return (index, photoPair, (high: variants.high, med: variants.medium, low: variants.low), videoData)
                    }
                    return (index, nil, nil, nil)
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
                    viewModel.preparedVideoData.append(result.videoData) // Store video data separately
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
    /// Now detects Live Photos and marks them appropriately
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
        typealias ProcessedAssetResult = (
            index: Int,
            asset: PHAsset,
            image: UIImage?,
            date: Date,
            isLivePhoto: Bool,
            error: Error?
        )

        // Process assets concurrently with controlled parallelism
        await withTaskGroup(of: ProcessedAssetResult.self) { group in
            // Add all tasks at once - TaskGroup handles concurrency automatically
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    do {
                        // Check if this is a Live Photo
                        let isLivePhoto = LivePhotoHelper.isLivePhoto(asset)

                        // Load image data using PHImageManager
                        let (_, image) = try await loadImageFromAsset(asset)

                        return (index, asset, image, asset.creationDate ?? Date(), isLivePhoto, nil)
                    } catch {
                        print("Failed to load asset at index \(index): \(error)")
                        return (index, asset, nil, asset.creationDate ?? Date(), false, error)
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
            let successfulAssets = sortedResults.compactMap { result -> (asset: PHAsset, image: UIImage, date: Date, isLivePhoto: Bool)? in
                guard let image = result.image else { return nil }
                return (asset: result.asset, image: image, date: result.date, isLivePhoto: result.isLivePhoto)
            }

            let errors = sortedResults.compactMap { $0.error }

            // Update view model with batch operation
            await MainActor.run {
                // Batch add all successful assets at once
                if !successfulAssets.isEmpty {
                    // Convert to old format for now (will be updated in Phase 3)
                    let simpleAssets = successfulAssets.map { (asset: $0.asset, image: $0.image, date: $0.date) }
                    viewModel.addProcessedAssets(simpleAssets)

                    // Track which assets are Live Photos for upload phase
                    for assetData in successfulAssets {
                        if assetData.isLivePhoto {
                            // Mark this asset as a Live Photo in the view model
                            viewModel.livePhotoAssets.insert(assetData.asset.localIdentifier)
                        }
                    }
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
