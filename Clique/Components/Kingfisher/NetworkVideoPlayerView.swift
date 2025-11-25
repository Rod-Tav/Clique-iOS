//
//  NetworkVideoPlayerView.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit
import AVFoundation

/// Displays a standalone video from network URLs with native Apple Photos-style controls.
///
/// Provides full-featured video playback matching the stock Photos app experience
/// with native player controls (play/pause, scrubber, volume, fullscreen).
///
/// ## Features
/// - **Auto-Play**: Starts playing automatically when view appears
/// - **Looping**: Video loops continuously
/// - **Native Controls**: Full AVPlayerViewController controls via ``AVPlayerViewControllerWrapper``
/// - **Muted by Default**: Starts muted, user can unmute via controls
/// - **HTTP Streaming**: Direct AVPlayer streaming with automatic URLCache management
/// - **Quality Selection**: Network-adaptive or manual quality override
///
/// ## Usage
/// ```swift
/// NetworkVideoPlayerView(
///     thumbnailUrl: image.imageUrl,
///     videoUrl: image.videoUrls,
///     quality: .high
/// )
/// ```
struct NetworkVideoPlayerView: View {
    let thumbnailUrl: MediaUrls?
    let videoUrl: MediaUrls?
    let quality: ImageQuality
    var forceQuality: Bool = false
    var isVisible: Bool = true
    var width: CGFloat? = nil
    var showControls: Bool = true
    var savedPosition: CMTime? = nil
    var onPositionSave: ((CMTime) -> Void)? = nil

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var isPaused: Bool = false

    var body: some View {
        ZStack {
            // Base layer: Video player or thumbnail
            if let player = player {
                if showControls {
                    // Full native controls mode (detail views)
                    if let width = width {
                        // Square format for feed cells
                        AVPlayerViewControllerWrapper(player: player)
                            .frame(width: width, height: width)
                            .clipped()
                            .onAppear {
                                player.play()
                            }
                    } else {
                        // Portrait format for detail views
                        AVPlayerViewControllerWrapper(player: player)
                            .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                            .onAppear {
                                player.play()
                            }
                    }
                } else {
                    // Controlless mode (feed cells)
                    if let width = width {
                        VideoPlayerView(player: player, shouldFill: true)
                            .frame(width: width, height: width)
                            .clipped()
                            .onAppear {
                                player.play()
                            }
                    } else {
                        VideoPlayerView(player: player, shouldFill: false)
                            .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                            .onAppear {
                                player.play()
                            }
                    }
                }
            } else {
                // Fallback: Show thumbnail while video loads
                if let width = width {
                    // Square format for feed cells
                    GenericAsyncImage(urls: thumbnailUrl, quality: quality) { image in
                        image
                            .contentConfigure { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: width, height: width)
                                    .clipped()
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(.gray)
                            .frame(width: width, height: width)
                    }
                } else {
                    // Portrait format for detail views
                    GenericAsyncImage(urls: thumbnailUrl, quality: quality) { image in
                        image
                            .contentConfigure { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                                    .clipped()
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(.gray)
                            .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                    }
                }
            }
        }
        .task(id: "\(quality.rawValue)-\(forceQuality)") {
            // Cleanup previous player when quality changes
            cleanup()

            // Get video URL with quality selection (auto or forced)
            let videoURL: URL?
            if forceQuality {
                videoURL = videoUrl?.videoUrl(for: quality, forceQuality: true)
            } else {
                videoURL = videoUrl?.videoUrl(for: quality)
            }

            guard let videoURL = videoURL else { return }

            // Create player with network URL for streaming
            // AVPlayer handles caching automatically via URLCache
            await MainActor.run {
                // Set audio session to ambient to prevent interrupting background music
                // This only sets the category, doesn't activate - so no interruption
                // When user unmutes, AVPlayerViewControllerWrapper will activate with .playback
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient)
                } catch {
                    print("⚠️ Failed to set ambient audio session: \(error.localizedDescription)")
                }

                player = AVPlayer(url: videoURL)
                player?.isMuted = true
                player?.actionAtItemEnd = .none

                // Setup looping
                if let currentItem = player?.currentItem {
                    setupLoopObserver(for: currentItem, player: player!)
                }

                // Restore saved playback position if available
                if let savedPosition = savedPosition, savedPosition.seconds > 0 {
                    player?.seek(to: savedPosition, toleranceBefore: .zero, toleranceAfter: .zero)
                }

                // Start playing immediately if visible (muted - audio session not needed)
                if isVisible {
                    player?.play()
                }
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                player?.play()
            } else {
                player?.pause()
                // Save current playback position when becoming invisible
                if let currentTime = player?.currentTime(), currentTime.seconds > 0 {
                    onPositionSave?(currentTime)
                }
            }
        }
        .onDisappear {
            // Save position before view disappears
            if let currentTime = player?.currentTime(), currentTime.seconds > 0 {
                onPositionSave?(currentTime)
            }
            // Only pause on disappear, don't cleanup
            // This preserves playback position when scrolling between videos
            player?.pause()
        }
    }

    /// Set up loop observer for video
    private func setupLoopObserver(for playerItem: AVPlayerItem, player: AVPlayer) {
        self.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()  // Auto-restart after loop
        }
    }

    /// Cleanup resources
    private func cleanup() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player?.pause()
        player = nil
    }
}

/// UIViewRepresentable wrapper for AVPlayer without controls
private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    let shouldFill: Bool

    func makeUIView(context: Context) -> VideoPlayerUIView {
        let view = VideoPlayerUIView()
        view.player = player
        view.shouldFill = shouldFill
        return view
    }

    func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
        uiView.player = player
        uiView.shouldFill = shouldFill
    }
}

/// Custom UIView that hosts an AVPlayerLayer
private class VideoPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?

    var player: AVPlayer? {
        didSet {
            if player !== oldValue {
                setupPlayerLayer()
            }
        }
    }

    var shouldFill: Bool = false {
        didSet {
            if shouldFill != oldValue {
                setupPlayerLayer()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    private func setupPlayerLayer() {
        playerLayer?.removeFromSuperlayer()

        guard let player = player else { return }
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = shouldFill ? .resizeAspectFill : .resizeAspect
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.playerLayer = layer
    }
}

#Preview {
    NetworkVideoPlayerView(
        thumbnailUrl: nil,
        videoUrl: nil,
        quality: .high
    )
}
