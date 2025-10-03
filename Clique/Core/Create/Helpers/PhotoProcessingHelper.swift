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
        let processedImageData = viewModel.processedImageData  // Capture to avoid concurrent access

        // Build image-to-asset lookup map for O(1) performance (avoid O(n²) complexity)
        let imageToAssetMap = Dictionary(uniqueKeysWithValues:
            assetsToProcess.compactMap { asset -> (ObjectIdentifier, PHAsset)? in
                guard let imageData = processedImageData[asset.localIdentifier] else { return nil }
                return (ObjectIdentifier(imageData.image), asset)
            }
        )

        // Define result type for clarity
        typealias ProcessResult = (
            index: Int,
            photoData: Components.Schemas.PhotoVideoDate?,
            variants: (high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)?,
            assetReference: (assetId: String, asset: PHAsset)?,  // For just-in-time video extraction
            assetIdentifier: String?,
            extractionError: Error?
        )

        await withTaskGroup(of: ProcessResult.self) { group in
            // Add all processing tasks
            for (index, image) in imagesToProcess.enumerated() {
                group.addTask {
                    let date = index < datesToProcess.count ? datesToProcess[index] : Date()

                    // Find the corresponding PHAsset for this image using O(1) lookup
                    let matchingAsset = imageToAssetMap[ObjectIdentifier(image)]

                    // Check if this is a Live Photo
                    let isLivePhoto = matchingAsset.map { livePhotoIdentifiers.contains($0.localIdentifier) } ?? false

                    // For Live Photos, get video file size without loading data (memory efficient)
                    var videoFileSize: Int64?
                    if isLivePhoto, let asset = matchingAsset {
                        // Get video file size from PHAssetResource (lightweight, no data extraction)
                        let resources = PHAssetResource.assetResources(for: asset)
                        if let videoResource = resources.first(where: { $0.type == .pairedVideo }) {
                            let unsignedSize = videoResource.value(forKey: "fileSize") as? Int ?? 0
                            videoFileSize = Int64(unsignedSize)
                            print("✅ Detected Live Photo video component (~\(videoFileSize ?? 0) bytes)")
                        }
                        // Note: Video data will be extracted just-in-time during upload to save memory
                    }

                    if let (photoData, variants) = prepareUIImage(image) {
                        // Prepare video metadata if this is a Live Photo (data extracted later)
                        var videoDataNoPath: Components.Schemas.VideoDataNoPath?
                        if isLivePhoto, let fileSize = videoFileSize {
                            // Backend expects video metadata (data will be uploaded separately)
                            videoDataNoPath = Components.Schemas.VideoDataNoPath(
                                baseVideo: Components.Schemas.UploadVideoParams(
                                    contentType: "video/quicktime",
                                    contentLength: fileSize
                                )
                            )
                        }

                        let photoPair = Components.Schemas.PhotoVideoDate(
                            photo: photoData,
                            video: videoDataNoPath,
                            mediaType: isLivePhoto ? .LIVE : .PHOTO,
                            dateCreated: convertFromDate(date)
                        )
                        // Return asset reference for Live Photos (for just-in-time video extraction)
                        let assetRef: (assetId: String, asset: PHAsset)?
                        if isLivePhoto, let asset = matchingAsset {
                            assetRef = (asset.localIdentifier, asset)
                        } else {
                            assetRef = nil
                        }

                        return (
                            index,
                            photoPair,
                            (high: variants.high, med: variants.medium, low: variants.low),
                            assetRef,
                            matchingAsset?.localIdentifier,
                            nil  // No extraction error at this point (extraction happens during upload)
                        )
                    }
                    return (index, nil, nil, nil, matchingAsset?.localIdentifier, nil)
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
                    // Store asset reference for just-in-time video extraction (memory efficient)
                    viewModel.livePhotoAssetReferences.append(result.assetReference)

                    // Track extraction errors for user notification
                    if let error = result.extractionError, let assetId = result.assetIdentifier {
                        viewModel.livePhotoExtractionErrors[assetId] = error
                    }
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
