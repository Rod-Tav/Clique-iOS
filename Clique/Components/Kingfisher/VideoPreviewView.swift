//
//  VideoPreviewView.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit
import Photos

/// Full-size video preview with native playback controls.
///
/// Provides video playback in the review/selected photos screen for locally selected videos.
///
/// ## Features
/// - **Local Video Playback**: Loads video directly from PHAsset (Photos library)
/// - **Native Controls**: Full AVPlayerViewController controls via ``AVPlayerViewControllerWrapper``
/// - **High-Quality Loading**: Loads full-quality video from device
/// - **Fallback Support**: Shows thumbnail while loading
/// - **Content Mode**: Configurable aspect ratio (fit/fill)
/// - **Transparent Background**: Clear background to show parent view
///
/// ## Usage
/// ```swift
/// VideoPreviewView(
///     asset: phAsset,
///     thumbnail: cachedThumbnail,
///     contentMode: .fit
/// )
/// ```
struct VideoPreviewView: View {
    /// The PHAsset to load video from
    let asset: PHAsset
    /// Optional cached thumbnail for immediate display
    let thumbnail: UIImage?
    /// Content mode for the video
    let contentMode: SwiftUI.ContentMode
    /// Whether this video is currently visible (controls playback)
    var isVisible: Bool = true

    @State private var player: AVPlayer?
    @State private var isLoading: Bool = true
    @State private var loadingError: Error?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let player = player {
                // Video loaded successfully - use AVPlayerViewController with visible controls
                AVPlayerViewControllerWrapper(player: player)
            } else if let thumbnail = thumbnail {
                // Show thumbnail while loading
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .overlay {
                        if isLoading {
                            ZStack {
                                Color.black.opacity(0.3)
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                            }
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
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                // Start loading video when becoming visible
                if player == nil && loadTask == nil {
                    loadTask = Task {
                        await loadVideo()
                    }
                }
                // Resume playback if already loaded
                player?.play()
            } else {
                // Cancel loading when becoming not visible
                loadTask?.cancel()
                loadTask = nil
                // Pause playback
                player?.pause()
            }
        }
        .onAppear {
            // Only load if currently visible
            if isVisible {
                loadTask = Task {
                    await loadVideo()
                }
            }
        }
        .onDisappear {
            // Cancel any ongoing load and pause
            loadTask?.cancel()
            loadTask = nil
            player?.pause()
        }
    }

    /// Load video from PHAsset
    private func loadVideo() async {
        isLoading = true

        do {
            let playerItem = try await loadPlayerItem(from: asset)

            await MainActor.run {
                let avPlayer = AVPlayer(playerItem: playerItem)
                self.player = avPlayer
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load video: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.loadingError = error
            }
        }
    }

    /// Load AVPlayerItem from PHAsset
    private func loadPlayerItem(from asset: PHAsset) async throws -> AVPlayerItem {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: options
            ) { playerItem, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let playerItem = playerItem else {
                    continuation.resume(throwing: VideoPreviewError.failedToLoadVideo)
                    return
                }

                continuation.resume(returning: playerItem)
            }
        }
    }
}

/// Error types for video preview
enum VideoPreviewError: LocalizedError {
    case failedToLoadVideo

    var errorDescription: String? {
        switch self {
        case .failedToLoadVideo:
            return "Failed to load video from asset"
        }
    }
}