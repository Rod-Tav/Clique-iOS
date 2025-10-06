//
//  NetworkLivePhotoPlayerView.swift
//  Clique
//
//  Created by Assistant on Native Live Photo playback implementation.
//

import SwiftUI
import AVKit

/// Displays a Live Photo from network URLs with native Apple Photos-like playback.
///
/// Replicates the iOS Photos app experience: shows a static image, and on long press,
/// seamlessly transitions to playing the video component in a loop with no visible controls.
///
/// ## Features
/// - **Long Press Playback**: Press and hold to play video, release to return to static image
/// - **Seamless Transitions**: Smooth opacity animations between image and video layers
/// - **Background Preloading**: Video loads immediately for instant playback
/// - **Looping**: Video loops continuously during press
/// - **No Controls**: Clean, native experience with no playback controls
///
/// ## Usage
/// ```swift
/// NetworkLivePhotoPlayerView(
///     imageUrl: image.imageUrl,
///     videoUrl: image.videoUrls,
///     quality: .high
/// )
/// ```
struct NetworkLivePhotoPlayerView: View {
    let imageUrl: MediaUrls?
    let videoUrl: MediaUrls?
    let quality: ImageQuality

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isVideoReady = false
    @State private var videoOpacity: Double = 0.0
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            // Base layer: Static image (always visible)
            GenericAsyncImage(urls: imageUrl, quality: quality) { image in
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

            // Overlay layer: Video player (fades in on long press)
            if let player = player {
                VideoPlayerView(player: player)
                    .opacity(videoOpacity)
                    .allowsHitTesting(false)  // Don't intercept gestures
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { pressing in
                    if pressing && isVideoReady {
                        startLivePhotoPlayback()
                    }
                }
                .onEnded { _ in
                    stopLivePhotoPlayback()
                }
        )
        .task {
            await preloadVideo()
        }
        .onDisappear {
            cleanup()
        }
    }

    /// Preload video in background for instant playback
    private func preloadVideo() async {
        guard let videoUrlString = videoUrl?.url(for: quality)?.absoluteString,
              let videoURL = URL(string: videoUrlString) else {
            print("⚠️ No video URL for Live Photo")
            return
        }

        print("🔄 Preloading Live Photo video: \(videoURL.lastPathComponent)")

        await MainActor.run {
            let avPlayer = AVPlayer(url: videoURL)
            avPlayer.isMuted = true  // Mute by default
            avPlayer.actionAtItemEnd = .none  // We'll handle looping manually

            // Observe when video is ready to play
            let playerItem = avPlayer.currentItem
            if playerItem?.status == .readyToPlay {
                self.isVideoReady = true
                print("✅ Live Photo video ready")
            } else {
                // Wait for ready state
                Task {
                    for await status in playerItem!.publisher(for: \.status).values {
                        if status == .readyToPlay {
                            await MainActor.run {
                                self.isVideoReady = true
                                print("✅ Live Photo video ready")
                            }
                            break
                        } else if status == .failed {
                            print("❌ Live Photo video failed to load")
                            break
                        }
                    }
                }
            }

            // Set up loop observer
            self.loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                // Loop video if still playing
                if self.isPlaying {
                    avPlayer.seek(to: .zero)
                    avPlayer.play()
                }
            }

            self.player = avPlayer
        }
    }

    /// Start Live Photo playback with smooth transition
    private func startLivePhotoPlayback() {
        guard let player = player, isVideoReady, !isPlaying else { return }

        isPlaying = true

        // Seek to beginning
        player.seek(to: .zero)

        // Smooth fade-in animation
        withAnimation(.easeInOut(duration: 0.15)) {
            videoOpacity = 1.0
        }

        // Start playback
        player.play()

        print("▶️ Live Photo playback started")
    }

    /// Stop Live Photo playback with smooth transition
    private func stopLivePhotoPlayback() {
        guard let player = player, isPlaying else { return }

        isPlaying = false

        // Smooth fade-out animation
        withAnimation(.easeInOut(duration: 0.15)) {
            videoOpacity = 0.0
        }

        // Pause playback and return to start
        player.pause()
        player.seek(to: .zero)

        print("⏸ Live Photo playback stopped")
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
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoPlayerUIView {
        let view = VideoPlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
        uiView.player = player
    }
}

/// Custom UIView that hosts an AVPlayerLayer
class VideoPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?

    var player: AVPlayer? {
        didSet {
            if player !== oldValue {
                setupPlayerLayer()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    private func setupPlayerLayer() {
        // Remove old layer
        playerLayer?.removeFromSuperlayer()

        // Create new layer
        guard let player = player else { return }
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect  // Match image scaling
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.playerLayer = layer
    }
}

#Preview {
    NetworkLivePhotoPlayerView(
        imageUrl: nil,
        videoUrl: nil,
        quality: .high
    )
}
