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

    func writeToPhotoAlbum(image: UIImage, date: Date, completion: @escaping (Bool) -> Void) {
        self.onComplete = completion

        // Directly perform the save operation without manually requesting authorization
        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }
            creationRequest.creationDate = date
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
    ///   - completion: Completion handler with success result
    func writeVideoToPhotoAlbum(videoUrl: URL, date: Date, completion: @escaping (Bool) -> Void) {
        self.onComplete = completion

        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: videoUrl, options: nil)
            // NOTE: Set creationDate as fallback for devices where video metadata isn't read
            // Photos will prefer video file metadata if present (preserving timezone),
            // but use this as fallback on devices that don't read video metadata
            creationRequest.creationDate = date
        } completionHandler: { success, error in
            if let error = error {
                print("❌ Failed to save video: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.onComplete?(success)
            }
        }
    }
}
