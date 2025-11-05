//
//  LivePhotoHelper.swift
//  Clique
//
//  Created by Assistant on Phase 2 implementation.
//

import Foundation
import Photos
import UIKit
import AVFoundation
import UniformTypeIdentifiers

/// Helper class for extracting and processing Live Photos
struct LivePhotoHelper {

    /// Video metadata extracted from Live Photo video component
    struct VideoMetadata {
        let duration: TimeInterval
        let size: CGSize
        let fileSize: Int64
        let codec: String?
    }

    /// Result of Live Photo extraction
    struct LivePhotoComponents {
        let stillImageData: Data
        let videoURL: URL  // Temp file URL for streaming upload (memory efficient)
        let stillImage: UIImage
        let creationDate: Date
        let videoMetadata: VideoMetadata

        /// Clean up temporary video file
        func cleanupVideoFile() {
            try? FileManager.default.removeItem(at: videoURL)
        }
    }

    // MARK: - Detection

    /// Checks if a PHAsset represents a Live Photo
    /// - Parameter asset: The asset to check
    /// - Returns: True if the asset is a Live Photo
    static func isLivePhoto(_ asset: PHAsset) -> Bool {
        return asset.isLivePhoto
    }

    // MARK: - Video Extraction (No Conversion)

    /// Extracts video from either a Live Photo or standalone video asset as-is (no transcoding)
    /// - Parameter asset: PHAsset (either Live Photo or video)
    /// - Returns: (videoFileURL, metadata, contentType) - Original video file for upload
    /// - Important: Call this during processing phase to get accurate file size before backend presigned URL request
    static func extractVideoWithoutTranscoding(from asset: PHAsset) async throws -> (URL, VideoMetadata, String) {
        let isLivePhoto = asset.isLivePhoto
        let isVideo = asset.isVideo

        guard isLivePhoto || isVideo else {
            throw LivePhotoError.notALivePhoto
        }

        let resources = PHAssetResource.assetResources(for: asset)

        // Find the video resource
        let videoResource: PHAssetResource?
        if isVideo {
            videoResource = resources.first(where: { $0.type == .video })
        } else {
            videoResource = resources.first(where: { $0.type == .pairedVideo })
        }

        guard let videoResource = videoResource else {
            throw LivePhotoError.noVideoComponent
        }

        // Determine file extension from resource type
        let fileExtension: String
        let contentType: String

        print("🔍 [UPLOAD-FORMAT] Detecting video format...")
        print("   UTI: \(videoResource.uniformTypeIdentifier)")

        // Check if this is a QuickTime/MOV file
        if videoResource.uniformTypeIdentifier.contains("quicktime") ||
           videoResource.uniformTypeIdentifier.contains("mov") {
            fileExtension = "mov"
            contentType = "video/quicktime"
            print("   ✅ Format: MOV (video/quicktime)")
        } else {
            // Default to MP4 for other video types
            fileExtension = "mp4"
            contentType = "video/mp4"
            print("   ✅ Format: MP4 (video/mp4)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Create temporary file with correct extension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(
                for: videoResource,
                toFile: tempURL,
                options: options
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                // Extract metadata from original file
                Task {
                    do {
                        let metadata = try await extractVideoMetadata(from: tempURL)
                        let sizeMB = Double(metadata.fileSize) / 1_048_576
                        print("✅ [UPLOAD-READY] Video extracted without conversion")
                        print("   Format: \(fileExtension.uppercased())")
                        print("   Content-Type: \(contentType)")
                        print("   Size: \(String(format: "%.2f", sizeMB)) MB (\(metadata.fileSize) bytes)")
                        print("   Duration: \(String(format: "%.1f", metadata.duration))s")
                        print("   Resolution: \(Int(metadata.size.width))x\(Int(metadata.size.height))")
                        if let codec = metadata.codec {
                            print("   Video Codec: \(codec)")
                        }

                        // Return original video URL for upload
                        continuation.resume(returning: (tempURL, metadata, contentType))
                    } catch {
                        try? FileManager.default.removeItem(at: tempURL)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Extraction

    /// Extracts both still image and video components from a Live Photo asset
    /// - Parameter asset: The PHAsset representing the Live Photo
    /// - Returns: LivePhotoComponents with video as temp file URL (memory efficient)
    /// - Throws: Error if extraction fails
    /// - Important: Caller must clean up temp file using `cleanupVideoFile()` after upload
    static func extractLivePhotoComponents(from asset: PHAsset) async throws -> LivePhotoComponents {
        guard isLivePhoto(asset) else {
            throw LivePhotoError.notALivePhoto
        }

        // Extract still image
        let (stillImageData, stillImage) = try await extractStillImage(from: asset)

        // Extract video to temp file (streaming-friendly)
        let (videoURL, videoMetadata, _) = try await extractVideoWithoutTranscoding(from: asset)

        let creationDate = asset.creationDate ?? Date()

        return LivePhotoComponents(
            stillImageData: stillImageData,
            videoURL: videoURL,
            stillImage: stillImage,
            creationDate: creationDate,
            videoMetadata: videoMetadata
        )
    }

    // MARK: - Private Helpers

    /// Extracts the still image component from a Live Photo
    private static func extractStillImage(from asset: PHAsset) async throws -> (Data, UIImage) {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, dataUTI, orientation, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    continuation.resume(throwing: LivePhotoError.failedToExtractStillImage)
                    return
                }

                continuation.resume(returning: (data, image))
            }
        }
    }


    /// Extracts metadata from a video file
    private static func extractVideoMetadata(from url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)

        // Get duration using modern async API
        let duration = try await CMTimeGetSeconds(asset.load(.duration))

        // Get video track using modern async API
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw LivePhotoError.failedToExtractVideoMetadata
        }

        // Get video size using modern async API
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let size = naturalSize.applying(preferredTransform)
        let videoSize = CGSize(width: abs(size.width), height: abs(size.height))

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Get codec using modern async API
        var codec: String?
        let formatDescriptions = try await videoTrack.load(.formatDescriptions) as [CMFormatDescription]
        if let formatDescription = formatDescriptions.first {
            let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
            codec = fourCharCodeToString(mediaSubType)
        }

        return VideoMetadata(
            duration: duration,
            size: videoSize,
            fileSize: fileSize,
            codec: codec
        )
    }

    /// Converts FourCharCode to string
    private static func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }

    // MARK: - Preview Loading

    /// Loads PHLivePhoto for preview/playback in the UI
    /// - Parameter asset: The PHAsset representing the Live Photo
    /// - Returns: Tuple of (PHLivePhoto, fallback UIImage)
    /// - Throws: Error if loading fails
    static func loadLivePhotoForPreview(from asset: PHAsset) async throws -> (livePhoto: PHLivePhoto?, fullImage: UIImage) {
        guard isLivePhoto(asset) else {
            throw LivePhotoError.notALivePhoto
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true // Important for iCloud photos

            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { livePhoto, info in
                // Check if this is the final result
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }

                // Also load a high-quality still image as fallback
                let imageOptions = PHImageRequestOptions()
                imageOptions.deliveryMode = .highQualityFormat
                imageOptions.isNetworkAccessAllowed = true
                imageOptions.isSynchronous = false
                imageOptions.resizeMode = .none  // Prevents iOS green tint bug with PHImageManagerMaximumSize

                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: imageOptions
                ) { image, imageInfo in
                    let isImageDegraded = (imageInfo?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    guard !isImageDegraded else { return }

                    if let image = image {
                        continuation.resume(returning: (livePhoto, image))
                    } else {
                        // If no image loaded, fail
                        continuation.resume(throwing: LivePhotoError.failedToExtractStillImage)
                    }
                }
            }
        }
    }
}

// MARK: - Error Types

enum LivePhotoError: LocalizedError {
    case notALivePhoto
    case failedToExtractStillImage
    case noVideoComponent
    case failedToExtractVideoMetadata
    case failedToTranscodeVideo
    case transcodingCancelled

    var errorDescription: String? {
        switch self {
        case .notALivePhoto:
            return "The asset is not a Live Photo"
        case .failedToExtractStillImage:
            return "Failed to extract still image from Live Photo"
        case .noVideoComponent:
            return "Live Photo does not have a video component"
        case .failedToExtractVideoMetadata:
            return "Failed to extract video metadata"
        case .failedToTranscodeVideo:
            return "Failed to transcode video to MP4"
        case .transcodingCancelled:
            return "Video transcoding was cancelled"
        }
    }
}