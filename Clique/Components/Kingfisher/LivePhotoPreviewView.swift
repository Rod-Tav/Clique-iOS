//
//  LivePhotoPreviewView.swift
//  Clique
//
//  Created by Assistant on Live Photos implementation.
//

import SwiftUI
import PhotosUI
import Photos

/// Full-size Live Photo preview with tap-and-hold playback support.
///
/// This component provides interactive Live Photo playback in the review/selected photos screen.
/// Users can tap and hold to play the Live Photo animation, or tap once for other interactions.
///
/// ## Features
/// - **Tap-and-Hold Playback**: Hold finger down to play Live Photo animation
/// - **High-Quality Loading**: Loads full-resolution Live Photo from PHAsset
/// - **Fallback Support**: Shows static image if Live Photo loading fails
/// - **Content Mode**: Configurable aspect ratio (fit/fill)
///
/// ## Usage
/// ```swift
/// LivePhotoPreviewView(
///     asset: phAsset,
///     thumbnail: cachedThumbnail,
///     contentMode: .fit
/// )
/// ```
struct LivePhotoPreviewView: View {
    /// The PHAsset to load Live Photo from
    let asset: PHAsset
    /// Optional cached thumbnail for immediate display
    let thumbnail: UIImage?
    /// Content mode for the image
    let contentMode: SwiftUI.ContentMode

    @State private var livePhoto: PHLivePhoto?
    @State private var fullImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var loadingError: Error?

    var body: some View {
        Group {
            if let livePhoto = livePhoto {
                // Live Photo loaded successfully - use PHLivePhotoView
                LivePhotoPlaybackView(
                    livePhoto: livePhoto,
                    contentMode: contentMode
                )
            } else if let fullImage = fullImage {
                // Fallback to static image
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let thumbnail = thumbnail {
                // Show thumbnail while loading
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
            } else {
                // Loading placeholder
                Color.theme.iconTertiary
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            }
        }
        .task {
            await loadLivePhoto()
        }
    }
    
    /// Load Live Photo from PHAsset
    private func loadLivePhoto() async {
        isLoading = true

        do {
            // First, try to load as Live Photo
            let (livePhoto, fullImage) = try await LivePhotoHelper.loadLivePhotoForPreview(from: asset)

            await MainActor.run {
                self.livePhoto = livePhoto
                self.fullImage = fullImage
                self.isLoading = false
            }
        } catch {
            // If Live Photo loading fails, load static image
            print("⚠️ Live Photo loading failed, falling back to static image: \(error)")

            do {
                let (_, image) = try await PhotoProcessingHelper.loadImageFromAsset(asset)
                await MainActor.run {
                    self.fullImage = image
                    self.isLoading = false
                    self.loadingError = error
                }
            } catch {
                print("❌ Failed to load static image: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.loadingError = error
                }
            }
        }
    }
}

/// UIViewRepresentable wrapper for PHLivePhotoView with tap-and-hold playback
struct LivePhotoPlaybackView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let contentMode: SwiftUI.ContentMode

    func makeUIView(context: Context) -> UIView {
        // Use a container view to properly handle SwiftUI frame constraints
        let container = UIView()
        container.clipsToBounds = true

        let livePhotoView = PHLivePhotoView()
        livePhotoView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        livePhotoView.livePhoto = livePhoto
        livePhotoView.clipsToBounds = true
        livePhotoView.translatesAutoresizingMaskIntoConstraints = false

        // Enable tap-to-play interaction (user can tap and hold to play)
        livePhotoView.isMuted = false

        container.addSubview(livePhotoView)

        // Pin livePhotoView to container edges
        NSLayoutConstraint.activate([
            livePhotoView.topAnchor.constraint(equalTo: container.topAnchor),
            livePhotoView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            livePhotoView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            livePhotoView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Store reference for updateUIView
        container.tag = 999

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let livePhotoView = container.subviews.first as? PHLivePhotoView else { return }

        // Force clear and reassign to ensure proper sizing recalculation
        // This fixes the issue where the same Live Photo appears oversized on second selection
        livePhotoView.livePhoto = nil
        livePhotoView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        livePhotoView.livePhoto = livePhoto

        // Force layout update to ensure proper sizing
        container.setNeedsLayout()
        container.layoutIfNeeded()
    }
}
