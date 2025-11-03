//
//  LivePhotoSaver.swift
//  Clique
//
//  Created by Rod Tavangar on 3/2/25.
//

import UIKit
import Photos
import AVFoundation
import Kingfisher

/// Actor-based wrapper for saving Live Photos with metadata injection
/// Handles download, metadata generation, and save operations with progress callbacks
actor LivePhotoSaver {

    // MARK: - Types

    enum LivePhotoError: Error {
        case downloadFailed(String)
        case metadataInjectionFailed(String)
        case saveFailed(String)
        case missingData
    }

    enum Progress {
        case downloading
        case processing
        case saving
        case completed
        case failed(Error)
    }

    typealias ProgressHandler = @MainActor (Progress) -> Void

    // MARK: - Properties

    private var tempImageURL: URL?
    private var tempVideoURL: URL?

    // MARK: - Public Interface

    /// Saves a Live Photo from network URLs with full metadata injection
    /// Falls back to video save if metadata injection fails
    ///
    /// - Parameters:
    ///   - imageUrl: URL of the still image
    ///   - videoUrl: URL of the video component
    ///   - date: Creation date for the Live Photo
    ///   - timezoneOffset: Optional timezone offset (e.g., "-0400") to preserve original timezone
    ///   - progressHandler: Callback for progress updates
    /// - Returns: Success result
    func saveLivePhoto(
        imageUrl: String,
        videoUrl: String,
        date: Date,
        timezoneOffset: String? = nil,
        progressHandler: ProgressHandler?
    ) async -> Bool {
        // Step 1: Download both components
        await progressHandler?(.downloading)

        do {
            // Download image using Kingfisher
            guard let imageURL = URL(string: imageUrl) else {
                throw LivePhotoError.downloadFailed("Invalid image URL")
            }

            let tempImageURL = try await downloadImageToFile(from: imageURL)

            // Download video using VideoCache
            guard let videoURL = URL(string: videoUrl) else {
                throw LivePhotoError.downloadFailed("Invalid video URL")
            }

            let localVideoURL = try await downloadVideo(from: videoURL)

            // Step 2: Generate Live Photo with metadata injection
            await progressHandler?(.processing)

            let resources = try await generateLivePhotoResources(
                imageURL: tempImageURL,
                videoURL: localVideoURL
            )

            // Step 3: Save to Photos Library
            await progressHandler?(.saving)

            let success = try await saveToPhotosLibrary(
                imageURL: resources.pairedImage,
                videoURL: resources.pairedVideo,
                date: date,
                timezoneOffset: timezoneOffset
            )

            if success {
                await progressHandler?(.completed)
            } else {
                throw LivePhotoError.saveFailed("Photos library rejected the Live Photo")
            }

            // Cleanup temp files
            await cleanup()

            return success

        } catch {
            print("❌ Live Photo save failed: \(error.localizedDescription)")
            await progressHandler?(.failed(error))
            await cleanup()

            // Fallback: Save as video instead
            print("⚠️ Falling back to video save")
            return await fallbackToVideoSave(videoUrl: videoUrl, date: date, timezoneOffset: timezoneOffset)
        }
    }

    // MARK: - Download Methods

    /// Downloads image and saves to temporary file
    private func downloadImageToFile(from url: URL) async throws -> URL {
        let imageURL = try await withCheckedThrowingContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case .success(let imageResult):
                    if let data = imageResult.image.jpegData(compressionQuality: 1.0) {
                        let tempDir = FileManager.default.temporaryDirectory
                        let imageURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")

                        do {
                            try data.write(to: imageURL)
                            continuation.resume(returning: imageURL)
                        } catch {
                            continuation.resume(throwing: LivePhotoError.downloadFailed("Failed to write image to temp file"))
                        }
                    } else {
                        continuation.resume(throwing: LivePhotoError.downloadFailed("Failed to get image data"))
                    }
                case .failure(let error):
                    continuation.resume(throwing: LivePhotoError.downloadFailed(error.localizedDescription))
                }
            }
        }

        // Store temp URL after await (back in actor context)
        self.tempImageURL = imageURL
        return imageURL
    }

    private func downloadVideo(from url: URL) async throws -> URL {
        do {
            return try await VideoCache.shared.getVideo(from: url)
        } catch {
            throw LivePhotoError.downloadFailed("Video download failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Live Photo Generation

    /// Generates Live Photo resources with metadata injection using LivePhoto library
    private func generateLivePhotoResources(
        imageURL: URL,
        videoURL: URL
    ) async throws -> (pairedImage: URL, pairedVideo: URL) {
        let resources = try await withCheckedThrowingContinuation { continuation in
            LivePhoto.generate(from: imageURL, videoURL: videoURL) { progress in
                // Progress callback - no logging to reduce noise
            } completion: { livePhoto, resources in
                if let resources = resources {
                    continuation.resume(returning: resources)
                } else {
                    continuation.resume(throwing: LivePhotoError.metadataInjectionFailed("LivePhoto generation failed"))
                }
            }
        }

        // Store temp URLs after await (back in actor context)
        self.tempImageURL = resources.pairedImage
        self.tempVideoURL = resources.pairedVideo
        return resources
    }

    // MARK: - Photos Library Save

    private func saveToPhotosLibrary(
        imageURL: URL,
        videoURL: URL,
        date: Date,
        timezoneOffset: String?
    ) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()

                // Add image resource
                let imageOptions = PHAssetResourceCreationOptions()
                imageOptions.shouldMoveFile = false
                creationRequest.addResource(
                    with: .photo,
                    fileURL: imageURL,
                    options: imageOptions
                )

                // Add paired video resource (this makes it a Live Photo)
                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.shouldMoveFile = false
                creationRequest.addResource(
                    with: .pairedVideo,
                    fileURL: videoURL,
                    options: videoOptions
                )

                // Adjust date to preserve original timezone when saving
                let adjustedDate = Self.adjustDateForSave(date, timezoneOffset: timezoneOffset)
                creationRequest.creationDate = adjustedDate

                print("📅 [SAVE] Original date: \(date)")
                print("📅 [SAVE] Timezone offset: \(timezoneOffset ?? "nil")")
                print("📅 [SAVE] Adjusted date: \(adjustedDate)")

            } completionHandler: { success, error in
                if let error = error {
                    print("❌ Failed to save Live Photo: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Date Adjustment

    /// Adjusts a Date object to preserve original timezone when saving to Photos
    ///
    /// iOS Photos interprets creationDate in the device's current timezone.
    /// To preserve the original timezone, we need to adjust the Date so that
    /// when iOS interprets it, it shows the correct original time.
    ///
    /// CRITICAL: For old photos uploaded before the fix, the Date object is wrong
    /// (parsed as UTC instead of in original timezone). We detect this and reconstruct
    /// the correct absolute time first, then apply the adjustment.
    ///
    /// Example (NEW photo - correct Date):
    /// - Photo taken: Oct 21, 8:05 PM EDT (-0400)
    /// - Date object: Oct 22, 00:05 UTC (correct absolute time)
    /// - Device timezone: PDT (-0700)
    /// - Adjustment: We want iOS to show 8:05 PM, so we adjust by timezone difference
    ///
    /// Example (OLD photo - wrong Date):
    /// - Photo taken: Oct 21, 8:05 PM EDT (-0400)
    /// - Date object: Oct 21, 20:05 UTC (wrong - parsed as UTC instead of EDT)
    /// - First reconstruct: 20:05 UTC + 4 hours = Oct 22, 00:05 UTC (correct)
    /// - Then apply device adjustment
    private static func adjustDateForSave(_ date: Date, timezoneOffset: String?) -> Date {
        guard let offset = timezoneOffset else {
            return date  // No adjustment if no timezone info
        }

        guard let timezone = TimeZone(offsetString: offset) else {
            return date  // Invalid timezone format
        }

        let originalOffset = timezone.secondsFromGMT(for: date)

        // CRITICAL FIX: For old photos, the Date was parsed as UTC but represents local time
        // Example: "20:05" in EXIF was parsed as "20:05 UTC" instead of "20:05 EDT"
        // We need to reconstruct the correct absolute time first
        // EDT is UTC-4, so: 20:05 EDT = 20:05 + 4 hours = 00:05 UTC (next day)
        // But originalOffset is -14400 (negative for EDT)
        // So we SUBTRACT the offset (which adds for negative values)
        let correctedDate = date.addingTimeInterval(TimeInterval(-originalOffset))

        // Now apply the save adjustment for iOS Photos
        let deviceOffset = TimeZone.current.secondsFromGMT(for: correctedDate)
        let saveAdjustment = TimeInterval(originalOffset - deviceOffset)

        return correctedDate.addingTimeInterval(saveAdjustment)
    }

    // MARK: - Fallback

    private func fallbackToVideoSave(videoUrl: String, date: Date, timezoneOffset: String?) async -> Bool {
        do {
            guard let url = URL(string: videoUrl) else {
                return false
            }

            let localVideoURL = try await VideoCache.shared.getVideo(from: url)

            return await withCheckedContinuation { continuation in
                let imageSaver = ImageSaver()
                imageSaver.writeVideoToPhotoAlbum(videoUrl: localVideoURL, date: date, timezoneOffset: timezoneOffset) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            print("❌ Fallback video save failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Cleanup

    private func cleanup() async {
        // Clean up temporary files
        if let imageURL = tempImageURL {
            try? FileManager.default.removeItem(at: imageURL)
            tempImageURL = nil
        }

        if let videoURL = tempVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
            tempVideoURL = nil
        }
    }
}
