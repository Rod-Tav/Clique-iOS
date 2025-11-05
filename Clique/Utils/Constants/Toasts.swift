//
//  Toasts.swift
//  Clique
//
//  Created by Rod Tavangar on 2/3/25.
//

import SwiftUI
import Toasts

struct Toasts {
    static let somethingWentWrong = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Something went wrong")
    
    static let uploadFailed = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Image upload failed")
    
    static let savedImage = ToastValue(icon: Image(systemName: "square.and.arrow.down"), message: "Saved to library")

    static let savedVideo = ToastValue(icon: Image(systemName: "square.and.arrow.down"), message: "Video saved to library")

    static let savingLivePhoto = ToastValue(icon: Image(systemName: "arrow.triangle.2.circlepath"), message: "Processing Live Photo...")

    static let savedLivePhoto = ToastValue(icon: Image(systemName: "square.and.arrow.down"), message: "Live Photo saved to library")

    static let downloadFromICloudFailed = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "One image download failed")
    
    static let imageOptimizationFailed = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Failed to process images")
    
    static let processingTimeout = ToastValue(icon: Image(systemName: "clock.badge.exclamationmark"), message: "Photo processing taking too long")
    
    static let memoryPressure = ToastValue(icon: Image(systemName: "memorychip"), message: "Not enough memory to process photos")
    
    static let cantLoadAsData = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Load as data failed")
    
    static let iosUpdateRequired = ToastValue(icon: Image(systemName: "arrow.up.circle.fill"), message: "Update to iOS 18.1+ to fix photo loading")
    
    static let deviceCantMessage = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "This device can't send messages.")
}

// MARK: Dynamic Toasts
extension Toasts {
    // New descriptive error toasts
    static func photoLoadError(errorCode: Int, errorDomain: String) -> ToastValue {
        ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Photo load failed: \(errorDomain) (\(errorCode))")
    }
    
    static func photoProcessingError(stage: String) -> ToastValue {
        ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Failed at: \(stage)")
    }
    
    static func iCloudError(description: String) -> ToastValue {
        ToastValue(icon: Image(systemName: "icloud.slash"), message: "iCloud: \(description)")
    }
    
    static func imageDataError(bytes: Int?) -> ToastValue {
        if let bytes = bytes {
            return ToastValue(icon: Image(systemName: "photo.badge.exclamationmark"), message: "Can't create image from \(bytes) bytes")
        } else {
            return ToastValue(icon: Image(systemName: "photo.badge.exclamationmark"), message: "No image data returned")
        }
    }
}

// MARK: Reports
extension Toasts {
    static let reportSuccess = ToastValue(icon: Image("check-circle-filled"), message: "Report sent")
    
    static let reportExists = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Report already exists")
    
    static let reportFailure = ToastValue(icon: Image(systemName: "exclamationmark.circle.fill"), message: "Error sending report")
}
