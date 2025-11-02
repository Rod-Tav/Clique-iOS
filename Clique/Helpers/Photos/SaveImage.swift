//
//  SaveImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/2/25.
//

import UIKit
import Photos

import UIKit
import Photos

class ImageSaver {
    var onComplete: ((Bool) -> Void)?

    func writeToPhotoAlbum(image: UIImage, date: Date, timezoneOffset: String? = nil, completion: @escaping (Bool) -> Void) {
        self.onComplete = completion

        // Directly perform the save operation without manually requesting authorization
        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }
            // Adjust date to preserve original timezone
            let adjustedDate = Self.adjustDateForSave(date, timezoneOffset: timezoneOffset)
            creationRequest.creationDate = adjustedDate
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                self.onComplete?(success)
            }
        }
    }

    /// Saves a video to the Photos library
    /// - Parameters:
    ///   - videoUrl: Local file URL of the video to save
    ///   - date: Creation date for the video
    ///   - timezoneOffset: Optional timezone offset (e.g., "-0400") to preserve original timezone
    ///   - completion: Completion handler with success result
    func writeVideoToPhotoAlbum(videoUrl: URL, date: Date, timezoneOffset: String? = nil, completion: @escaping (Bool) -> Void) {
        self.onComplete = completion

        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: videoUrl, options: nil)
            // Adjust date to preserve original timezone
            let adjustedDate = Self.adjustDateForSave(date, timezoneOffset: timezoneOffset)
            creationRequest.creationDate = adjustedDate
        } completionHandler: { success, error in
            if let error = error {
                print("❌ Failed to save video: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.onComplete?(success)
            }
        }
    }

    /// Adjusts a Date object to preserve original timezone when saving to Photos
    ///
    /// iOS Photos interprets creationDate in the device's current timezone.
    /// For old photos, the Date was parsed as UTC but represents local time,
    /// so we reconstruct the correct absolute time first.
    private static func adjustDateForSave(_ date: Date, timezoneOffset: String?) -> Date {
        guard let offset = timezoneOffset else {
            return date  // No adjustment if no timezone info
        }

        guard let timezone = TimeZone(offsetString: offset) else {
            return date  // Invalid timezone format
        }

        let originalOffset = timezone.secondsFromGMT(for: date)

        // For old photos: Date was parsed as UTC but represents local time
        // Reconstruct correct absolute time first
        let correctedDate = date.addingTimeInterval(TimeInterval(originalOffset))

        // Apply save adjustment for iOS Photos
        let deviceOffset = TimeZone.current.secondsFromGMT(for: correctedDate)
        let saveAdjustment = TimeInterval(originalOffset - deviceOffset)

        return correctedDate.addingTimeInterval(saveAdjustment)
    }
}
