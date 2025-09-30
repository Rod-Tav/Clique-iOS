//
//  VideoPreviewView.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit
import Photos

/// Full-size video preview with playback controls.
///
/// This component provides video playback in the review/selected photos screen.
/// Users can tap to play/pause and scrub through the video.
///
/// ## Features
/// - **Video Playback**: Uses AVPlayer for smooth video playback
/// - **Playback Controls**: Standard iOS video controls overlay
/// - **High-Quality Loading**: Loads full-quality video from PHAsset
/// - **Fallback Support**: Shows thumbnail while loading
/// - **Content Mode**: Configurable aspect ratio (fit/fill)
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

    @State private var player: AVPlayer?
    @State private var isLoading: Bool = true
    @State private var loadingError: Error?
    @State private var videoDidComplete: Bool = false

    var body: some View {
        Group {
            if let player = player {
                // Video loaded successfully - use AVPlayerViewController with visible controls
                VideoPlayerWithControls(player: player)
                    .onAppear {
                        // Reset completion flag when reappearing
                        videoDidComplete = false
                        // Auto-play video when view appears
                        player.play()
                    }
                    .onDisappear {
                        // Pause video
                        player.pause()
                        // Only reset to beginning if video completed naturally
                        if videoDidComplete {
                            player.seek(to: .zero)
                            videoDidComplete = false
                        }
                        // Otherwise preserve position for resuming later
                    }
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
        .task {
            await loadVideo()
        }
    }

    /// Load video from PHAsset
    private func loadVideo() async {
        isLoading = true

        do {
            let playerItem = try await loadPlayerItem(from: asset)

            await MainActor.run {
                let avPlayer = AVPlayer(playerItem: playerItem)

                // Observe when video finishes playing naturally
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { [self] _ in
                    self.videoDidComplete = true
                }

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

/// UIViewControllerRepresentable wrapper for AVPlayerViewController with always-visible controls
struct VideoPlayerWithControls: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
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