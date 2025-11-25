//
//  CollectionImageShareHelpers.swift
//  Clique
//
//  Created by Assistant for shared image/video/live photo sharing functionality.
//

import Foundation
import SwiftUI
import Toasts
import Photos
import PhotosUI
import UniformTypeIdentifiers
import Kingfisher

/// Shared helper functions for sharing collection images
/// Provides on-demand loading and native iOS share sheet for all media types
struct CollectionImageShareHelpers {

    /// Handles sharing a static image
    /// - Parameters:
    ///   - image: The collection image to share
    ///   - presentToast: Toast presentation closure (only for errors)
    ///   - presentShareSheet: Closure to present the share sheet with file URL
    @MainActor
    static func shareImage(
        image: CollectionImage,
        presentToast: @escaping (ToastValue) -> Void,
        presentShareSheet: @escaping (URL) -> Void
    ) async {
        guard let imageUrl = image.imageUrl,
              let url = imageUrl.highQualityUrl else { return }

        guard let loadedImage = await fetchImageWithKingfisher(from: url) else {
            presentToast(Toasts.somethingWentWrong)
            return
        }

        // Save to temp file for proper preview in share sheet
        guard let imageData = loadedImage.jpegData(compressionQuality: 0.9) else {
            presentToast(Toasts.somethingWentWrong)
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")

        do {
            try imageData.write(to: tempFileURL)
            presentShareSheet(tempFileURL)
        } catch {
            print("❌ Failed to write image to temp file: \(error)")
            presentToast(Toasts.somethingWentWrong)
        }
    }

    /// Handles sharing a video
    /// - Parameters:
    ///   - image: The collection image to share
    ///   - presentToast: Toast presentation closure (only for errors)
    ///   - presentShareSheet: Closure to present the share sheet with file URL
    @MainActor
    static func shareVideo(
        image: CollectionImage,
        presentToast: @escaping (ToastValue) -> Void,
        presentShareSheet: @escaping (URL) -> Void
    ) async {
        guard let videoUrl = image.videoUrls?.highQualityUrl else { return }

        do {
            // Download video to local file
            let videoLocalUrl = try await VideoCache.shared.getVideo(from: URL(string: videoUrl)!)
            presentShareSheet(videoLocalUrl)
        } catch {
            print("❌ Failed to share video: \(error)")
            presentToast(Toasts.somethingWentWrong)
        }
    }

    /// Handles sharing a Live Photo (shares the still image component only)
    /// Note: UIActivityViewController cannot reliably share Live Photos to iMessage with animation preserved.
    /// Users should use the "Save" button to save to their library, then share from Photos app.
    /// - Parameters:
    ///   - image: The collection image to share
    ///   - presentToast: Toast presentation closure
    ///   - presentShareSheet: Closure to present the share sheet with file URL
    @MainActor
    static func shareLivePhoto(
        image: CollectionImage,
        presentToast: @escaping (ToastValue) -> Void,
        presentShareSheet: @escaping (URL) -> Void
    ) async {
        // For Live Photos, just share the still image component
        // The video component cannot be reliably shared as a Live Photo via UIActivityViewController
        await shareImage(
            image: image,
            presentToast: presentToast,
            presentShareSheet: presentShareSheet
        )
    }

    // MARK: - Private Helpers

    /// Downloads image and saves to temporary file
    private static func downloadImageToFile(from url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
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
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: NSError(domain: "ShareHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image data"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Generates Live Photo with metadata injection
    /// Returns both the PHLivePhoto object and the resource files
    private static func generateLivePhoto(
        imageURL: URL,
        videoURL: URL
    ) async throws -> (livePhoto: PHLivePhoto, pairedImage: URL, pairedVideo: URL) {
        return try await withCheckedThrowingContinuation { continuation in
            LivePhoto.generate(from: imageURL, videoURL: videoURL) { progress in
                // Progress callback
            } completion: { livePhoto, resources in
                if let livePhoto = livePhoto, let resources = resources {
                    continuation.resume(returning: (livePhoto, resources.pairedImage, resources.pairedVideo))
                } else {
                    continuation.resume(throwing: NSError(domain: "ShareHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "LivePhoto generation failed"]))
                }
            }
        }
    }

    /// Generates Live Photo resources with metadata injection (for saving)
    private static func generateLivePhotoResources(
        imageURL: URL,
        videoURL: URL
    ) async throws -> (pairedImage: URL, pairedVideo: URL) {
        let result = try await generateLivePhoto(imageURL: imageURL, videoURL: videoURL)
        return (result.pairedImage, result.pairedVideo)
    }

    /// Creates PHLivePhoto specifically for sharing (more lenient than save version)
    /// Accepts degraded Live Photos since sharing should work even with lower quality
    private static func createPHLivePhotoForSharing(
        imageURL: URL,
        videoURL: URL
    ) async throws -> PHLivePhoto {
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            print("🔴 [LIVE PHOTO SHARE] Requesting PHLivePhoto...")

            PHLivePhoto.request(
                withResourceFileURLs: [imageURL, videoURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                guard !resumed else {
                    print("🔴 [LIVE PHOTO SHARE] Skipping duplicate callback")
                    return
                }

                let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info[PHLivePhotoInfoCancelledKey] as? Bool) ?? false

                print("🔴 [LIVE PHOTO SHARE] Callback - degraded: \(isDegraded), cancelled: \(isCancelled), hasPhoto: \(livePhoto != nil)")

                // Check for error
                if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                    print("🔴 [LIVE PHOTO SHARE] ❌ Error: \(error)")
                    resumed = true
                    continuation.resume(throwing: error)
                    return
                }

                // Check if cancelled
                if isCancelled {
                    print("🔴 [LIVE PHOTO SHARE] ❌ Cancelled")
                    resumed = true
                    continuation.resume(throwing: NSError(domain: "ShareHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Live Photo creation cancelled"]))
                    return
                }

                // For sharing, accept even degraded Live Photos
                // We just need ANY valid PHLivePhoto object
                if let livePhoto = livePhoto {
                    print("🔴 [LIVE PHOTO SHARE] ✅ Got Live Photo (degraded: \(isDegraded))")
                    resumed = true
                    continuation.resume(returning: livePhoto)
                }
            }
        }
    }

    /// Creates PHLivePhoto object from paired resource files
    /// Handles multiple callbacks by checking isDegraded flag
    private static func createPHLivePhotoSafely(
        imageURL: URL,
        videoURL: URL
    ) async throws -> PHLivePhoto {
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            print("🔴 [LIVE PHOTO] Requesting PHLivePhoto with:")
            print("   Image: \(imageURL.lastPathComponent)")
            print("   Video: \(videoURL.lastPathComponent)")

            PHLivePhoto.request(
                withResourceFileURLs: [imageURL, videoURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                guard !resumed else {
                    print("🔴 [LIVE PHOTO] Callback skipped (already resumed)")
                    return
                }

                let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info[PHLivePhotoInfoCancelledKey] as? Bool) ?? false

                print("🔴 [LIVE PHOTO] Callback received:")
                print("   isDegraded: \(isDegraded)")
                print("   isCancelled: \(isCancelled)")
                print("   livePhoto: \(livePhoto != nil ? "✅" : "❌")")
                print("   info keys: \(info.keys)")

                // Handle error first
                if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                    print("🔴 [LIVE PHOTO] ❌ Error: \(error)")
                    resumed = true
                    continuation.resume(throwing: error)
                    return
                }

                // Check if cancelled
                if isCancelled {
                    print("🔴 [LIVE PHOTO] ❌ Live Photo creation was cancelled")
                    resumed = true
                    continuation.resume(throwing: NSError(domain: "ShareHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Live Photo creation was cancelled"]))
                    return
                }

                // Only resume with a non-degraded Live Photo
                if let livePhoto = livePhoto, !isDegraded {
                    print("🔴 [LIVE PHOTO] ✅ Success - resuming with Live Photo")
                    resumed = true
                    continuation.resume(returning: livePhoto)
                } else if !isDegraded && livePhoto == nil {
                    print("🔴 [LIVE PHOTO] ❌ No Live Photo and no error")
                    resumed = true
                    continuation.resume(throwing: NSError(domain: "ShareHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Live Photo"]))
                }
            }
        }
    }

}

/// SwiftUI wrapper for UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )

        // Call onDismiss when the activity view controller completes
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

/// View modifier to present share sheet
struct ShareSheetModifier: ViewModifier {
    @Binding var shareItem: ShareItem?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { shareItem != nil },
                set: { if !$0 { shareItem = nil } }
            )) {
                if let shareItem {
                    ActivityViewController(
                        activityItems: shareItem.items,
                        applicationActivities: nil,
                        onDismiss: { self.shareItem = nil }
                    )
                }
            }
    }
}

/// Wrapper for sharable items
enum ShareItem: Identifiable {
    case url(URL)

    var id: String {
        switch self {
        case .url(let url):
            return url.absoluteString
        }
    }

    var items: [Any] {
        switch self {
        case .url(let url):
            return [url]
        }
    }
}

extension View {
    /// Adds share sheet presentation capability
    func shareSheet(item: Binding<ShareItem?>) -> some View {
        modifier(ShareSheetModifier(shareItem: item))
    }
}
