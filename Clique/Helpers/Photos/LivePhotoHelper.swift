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
        return asset.mediaSubtypes.contains(.photoLive)
    }

    // MARK: - Video Extraction (Pre-Processing)

    /// Extracts and transcodes video from either a Live Photo or standalone video asset
    /// - Parameter asset: PHAsset (either Live Photo or video)
    /// - Returns: (mp4FileURL, metadata) - Pre-transcoded for upload
    /// - Important: Call this during processing phase to get accurate file size before backend presigned URL request
    static func extractAndTranscodeVideo(from asset: PHAsset) async throws -> (URL, VideoMetadata) {
        let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
        let isVideo = asset.mediaType == .video

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

        return try await withCheckedThrowingContinuation { continuation in
            // Create temporary file for video (will be transcoded to MP4)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

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

                // Prepare video for backend (rename to .mp4, backend's ffmpeg handles MOV)
                Task {
                    do {
                        print("📦 Preparing \(isVideo ? "video" : "Live Photo video") for upload...")
                        let mp4URL = try await transcodeToMP4(from: tempURL)

                        // Clean up original .mov file
                        try? FileManager.default.removeItem(at: tempURL)

                        // Extract metadata
                        let metadata = try extractVideoMetadata(from: mp4URL)
                        print("✅ Video ready for upload: \(metadata.fileSize) bytes")

                        // Return prepared video URL for upload
                        continuation.resume(returning: (mp4URL, metadata))
                    } catch {
                        // Clean up both files on error
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
        let (videoURL, videoMetadata) = try await extractVideo(from: asset)

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

    /// Extracts and transcodes the video component from a Live Photo to MP4
    /// - Returns: (mp4FileURL, metadata) - Caller responsible for cleanup
    /// - Important: Memory-efficient - transcodes via file, not in-memory. Returns MP4 file URL for streaming.
    private static func extractVideo(from asset: PHAsset) async throws -> (URL, VideoMetadata) {
        // Request video resources for the Live Photo
        let resources = PHAssetResource.assetResources(for: asset)

        // Find the paired video resource
        guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
            throw LivePhotoError.noVideoComponent
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Create temporary file for video (will be streamed for upload, not loaded into memory)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

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

                // Prepare video for backend (rename to .mp4, backend's ffmpeg handles MOV)
                Task {
                    do {
                        print("📦 Preparing Live Photo video for upload...")
                        let mp4URL = try await transcodeToMP4(from: tempURL)

                        // Clean up original .mov file
                        try? FileManager.default.removeItem(at: tempURL)

                        // Extract metadata
                        let metadata = try extractVideoMetadata(from: mp4URL)

                        // Return prepared video URL for upload
                        continuation.resume(returning: (mp4URL, metadata))
                    } catch {
                        // Clean up both files on error
                        try? FileManager.default.removeItem(at: tempURL)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// "Transcodes" a video file by simply renaming MOV to MP4
    ///
    /// **IMPORTANT**: This doesn't actually transcode - it just renames the file.
    /// The backend receives the raw MOV file with content-type "video/mp4", but ffmpeg
    /// doesn't care about the extension and will process MOV files correctly.
    ///
    /// This bypasses the broken AVAssetExportSession transcoding which created
    /// MP4 files that wouldn't play in AVPlayer.
    ///
    /// - Parameter sourceURL: Source .mov file URL
    /// - Returns: URL of "transcoded" .mp4 file (actually just renamed MOV)
    /// - Important: Caller must clean up both source and output files
    private static func transcodeToMP4(from sourceURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // Just copy the MOV file and change extension to .mp4
        // Backend's ffmpeg will process it correctly regardless of extension
        try FileManager.default.copyItem(at: sourceURL, to: outputURL)

        print("✅ Prepared video for upload (MOV → MP4 rename): \(outputURL.lastPathComponent)")

        return outputURL
    }

    /// Extracts metadata from a video file
    private static func extractVideoMetadata(from url: URL) throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)

        // Get duration
        let duration = CMTimeGetSeconds(asset.duration)

        // Get video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw LivePhotoError.failedToExtractVideoMetadata
        }

        // Get video size
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let videoSize = CGSize(width: abs(size.width), height: abs(size.height))

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Get codec
        var codec: String?
        if let formatDescriptions = videoTrack.formatDescriptions as? [CMFormatDescription],
           let formatDescription = formatDescriptions.first {
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