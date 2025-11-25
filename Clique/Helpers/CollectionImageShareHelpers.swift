//
//  CollectionImageShareHelpers.swift
//  Clique
//
//  Created by Assistant for shared image/video sharing functionality.
//

import Foundation
import SwiftUI
import Toasts
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

    /// Fetches an image using Kingfisher
    private static func fetchImageWithKingfisher(from url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case .success(let imageResult):
                    continuation.resume(returning: imageResult.image)
                case .failure:
                    continuation.resume(returning: nil)
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
