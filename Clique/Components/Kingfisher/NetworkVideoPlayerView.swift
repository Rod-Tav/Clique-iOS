//
//  NetworkVideoPlayerView.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit

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
/// - **Local Caching**: Videos cached via ``VideoCache`` for instant playback
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
    let forceQuality: Bool
    let isVisible: Bool
    let width: CGFloat?
    let showControls: Bool

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var isPaused: Bool = false

    init(thumbnailUrl: MediaUrls?, videoUrl: MediaUrls?, quality: ImageQuality, forceQuality: Bool = false, isVisible: Bool = true, width: CGFloat? = nil, showControls: Bool = true) {
        self.thumbnailUrl = thumbnailUrl
        self.videoUrl = videoUrl
        self.quality = quality
        self.forceQuality = forceQuality
        self.isVisible = isVisible
        self.width = width
        self.showControls = showControls
    }

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
                                configureAudioSession()
                                player.play()
                            }
                    } else {
                        // Portrait format for detail views
                        AVPlayerViewControllerWrapper(player: player)
                            .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                            .onAppear {
                                configureAudioSession()
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
                                configureAudioSession()
                                player.play()
                            }
                    } else {
                        VideoPlayerView(player: player, shouldFill: false)
                            .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                            .onAppear {
                                configureAudioSession()
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

            do {
                // Download and cache video (returns local URL)
                let localURL = try await VideoCache.shared.getVideo(from: videoURL)

                // Create player with local cached URL
                await MainActor.run {
                    player = AVPlayer(url: localURL)
                    player?.isMuted = true
                    player?.actionAtItemEnd = .none

                    // Setup looping
                    if let currentItem = player?.currentItem {
                        setupLoopObserver(for: currentItem, player: player!)
                    }
                }
            } catch {
                print("❌ Video playback failed: \(error.localizedDescription)")
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            cleanup()
        }
    }

    /// Configure audio session for playback
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error.localizedDescription)")
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
