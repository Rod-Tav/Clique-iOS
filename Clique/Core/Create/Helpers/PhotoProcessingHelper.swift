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
            variant: PreparedImageVariant?,
            assetReference: (assetId: String, asset: PHAsset)?,  // For just-in-time video extraction (standalone videos only)
            assetIdentifier: String?,
            extractionError: Error?,
            transcodedVideoUrl: URL?  // Pre-transcoded video URL (for Live Photos and videos)
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
                    // Check if this is a standalone video
                    let isVideo = matchingAsset?.mediaType == .video

                    // For Live Photos and standalone videos, extract and transcode video NOW (before backend call)
                    var videoFileSize: Int64?
                    var transcodedVideoUrl: URL?
                    var videoExtractionError: Error?

                    if (isLivePhoto || isVideo), let asset = matchingAsset {
                        print("🎥 Processing \(isVideo ? "standalone video" : "Live Photo") - Asset ID: \(asset.localIdentifier)")
                        do {
                            // Extract and transcode video to MP4 to get accurate file size
                            let (videoUrl, metadata) = try await LivePhotoHelper.extractAndTranscodeVideo(from: asset)
                            videoFileSize = metadata.fileSize
                            transcodedVideoUrl = videoUrl

                            if isVideo {
                                print("✅ Transcoded standalone video: \(videoFileSize ?? 0) bytes, URL: \(videoUrl)")
                            } else {
                                print("✅ Transcoded Live Photo video: \(videoFileSize ?? 0) bytes, URL: \(videoUrl)")
                            }
                        } catch {
                            print("❌ Failed to extract/transcode \(isVideo ? "video" : "Live Photo"): \(error)")
                            print("   Asset ID: \(asset.localIdentifier)")
                            print("   Will fall back to PHOTO mode")
                            videoExtractionError = error
                            // Continue with photo upload even if video fails
                        }
                    }

                    if let (photoData, variant) = prepareUIImage(image) {
                        // Prepare video metadata if this is a Live Photo or standalone video
                        var videoDataNoPath: Components.Schemas.VideoDataNoPath?
                        if (isLivePhoto || isVideo), let fileSize = videoFileSize {
                            // Backend validates and requires video/mp4 content type
                            // Use actual transcoded MP4 file size (not original .mov size)
                            videoDataNoPath = Components.Schemas.VideoDataNoPath(
                                baseVideo: Components.Schemas.UploadVideoParams(
                                    contentType: "video/mp4",
                                    contentLength: fileSize
                                )
                            )
                            print("📦 Created video metadata - Type: \(isVideo ? "VIDEO" : "LIVE"), Size: \(fileSize) bytes")
                        } else if isLivePhoto || isVideo {
                            print("⚠️ Skipping video metadata - extraction failed or fileSize is nil")
                            print("   isVideo: \(isVideo), isLivePhoto: \(isLivePhoto), videoFileSize: \(String(describing: videoFileSize))")
                        }

                        // Determine media type based on what data we actually have
                        let finalMediaType: Components.Schemas.MediaType
                        if isVideo {
                            if videoDataNoPath != nil {
                                finalMediaType = .VIDEO
                                print("📸 Media type: VIDEO (with video data)")
                            } else {
                                finalMediaType = .PHOTO
                                print("⚠️ Media type: PHOTO (video extraction failed for standalone video)")
                            }
                        } else if isLivePhoto {
                            if videoDataNoPath != nil {
                                finalMediaType = .LIVE
                                print("📸 Media type: LIVE (with video data)")
                            } else {
                                finalMediaType = .PHOTO
                                print("⚠️ Media type: PHOTO (video extraction failed for Live Photo)")
                            }
                        } else {
                            finalMediaType = .PHOTO
                            print("📸 Media type: PHOTO (regular photo)")
                        }

                        let photoPair = Components.Schemas.PhotoVideoDate(
                            photo: photoData,
                            video: videoDataNoPath,
                            mediaType: finalMediaType,
                            dateCreated: convertFromDate(date)
                        )

                        print("✅ Created PhotoVideoDate - mediaType: \(finalMediaType.rawValue), hasVideo: \(videoDataNoPath != nil)")
                        // Return asset reference (kept for backward compatibility, but video is already transcoded)
                        let assetRef: (assetId: String, asset: PHAsset)?
                        if (isLivePhoto || isVideo), let asset = matchingAsset {
                            assetRef = (asset.localIdentifier, asset)
                        } else {
                            assetRef = nil
                        }

                        return (
                            index,
                            photoPair,
                            variant,
                            assetRef,
                            matchingAsset?.localIdentifier,
                            videoExtractionError,  // Track extraction errors
                            transcodedVideoUrl     // Pre-transcoded video URL
                        )
                    }
                    return (index, nil, nil, nil, matchingAsset?.localIdentifier, nil, nil)
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
                if let photoData = result.photoData, let variant = result.variant {
                    viewModel.photoDatePairs.append(photoData)
                    viewModel.preparedImageVariants.append(variant)
                    // Store asset reference (for backward compatibility)
                    viewModel.livePhotoAssetReferences.append(result.assetReference)
                    // Store pre-transcoded video URL (critical for presigned URL signature matching)
                    viewModel.transcodedVideoUrls.append(result.transcodedVideoUrl)

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
