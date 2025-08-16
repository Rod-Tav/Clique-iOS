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
}
