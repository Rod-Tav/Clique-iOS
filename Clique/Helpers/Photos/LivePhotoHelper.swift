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
        let videoData: Data
        let stillImage: UIImage
        let creationDate: Date
        let videoMetadata: VideoMetadata
    }

    // MARK: - Detection

    /// Checks if a PHAsset represents a Live Photo
    /// - Parameter asset: The asset to check
    /// - Returns: True if the asset is a Live Photo
    static func isLivePhoto(_ asset: PHAsset) -> Bool {
        return asset.mediaSubtypes.contains(.photoLive)
    }

    // MARK: - Extraction

    /// Extracts both still image and video components from a Live Photo asset
    /// - Parameter asset: The PHAsset representing the Live Photo
    /// - Returns: LivePhotoComponents containing both still image and video data
    /// - Throws: Error if extraction fails
    static func extractLivePhotoComponents(from asset: PHAsset) async throws -> LivePhotoComponents {
        guard isLivePhoto(asset) else {
            throw LivePhotoError.notALivePhoto
        }

        // Extract still image
        let (stillImageData, stillImage) = try await extractStillImage(from: asset)

        // Extract video
        let (videoData, videoMetadata) = try await extractVideo(from: asset)

        let creationDate = asset.creationDate ?? Date()

        return LivePhotoComponents(
            stillImageData: stillImageData,
            videoData: videoData,
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

    /// Extracts the video component from a Live Photo
    private static func extractVideo(from asset: PHAsset) async throws -> (Data, VideoMetadata) {
        // Request video resources for the Live Photo
        let resources = PHAssetResource.assetResources(for: asset)

        // Find the paired video resource
        guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
            throw LivePhotoError.noVideoComponent
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Create temporary file for video
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

                do {
                    // Read video data
                    let videoData = try Data(contentsOf: tempURL)

                    // Extract metadata
                    let metadata = try extractVideoMetadata(from: tempURL)

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)

                    continuation.resume(returning: (videoData, metadata))
                } catch {
                    // Clean up temp file on error
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(throwing: error)
                }
            }
        }
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
}

// MARK: - Error Types

enum LivePhotoError: LocalizedError {
    case notALivePhoto
    case failedToExtractStillImage
    case noVideoComponent
    case failedToExtractVideoMetadata

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
        }
    }
}