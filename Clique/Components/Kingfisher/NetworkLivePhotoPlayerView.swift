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
    @State private var loadingError: String? = nil
    @GestureState private var isLongPressing = false

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
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.1)
                .updating($isLongPressing) { currentState, gestureState, _ in
                    gestureState = currentState
                }
        )
        .onChange(of: isLongPressing) { oldValue, newValue in
            if newValue && isVideoReady {
                startLivePhotoPlayback()
            } else if !newValue && isPlaying {
                stopLivePhotoPlayback()
            }
        }
        .task {
            await preloadVideo()
        }
        .onDisappear {
            cleanup()
        }
    }

    /// Preload video in background for instant playback
    private func preloadVideo() async {
        guard let videoURL = videoUrl?.videoUrl(for: quality) else {
            print("⚠️ No video URL for Live Photo")
            print("   videoUrl: \(String(describing: videoUrl))")
            print("   quality: \(quality)")
            return
        }

        print("🔄 Downloading and caching Live Photo video: \(videoURL.lastPathComponent)")
        print("   S3 URL: \(videoURL.absoluteString)")

        // Download and cache video with .mp4 extension
        let cachedURL: URL
        do {
            cachedURL = try await VideoCache.shared.getVideo(from: videoURL)
            print("✅ Live Photo video cached at: \(cachedURL.path)")
        } catch {
            print("❌ Failed to cache Live Photo video: \(error.localizedDescription)")
            await MainActor.run {
                self.loadingError = "Failed to download Live Photo video"
            }
            return
        }

        // Configure audio session before creating player
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("✅ Audio session configured for Live Photo playback")
        } catch {
            print("⚠️ Failed to configure audio session: \(error.localizedDescription)")
        }

        // Create player on main thread with cached local URL
        let avPlayer = await MainActor.run {
            let player = AVPlayer(url: cachedURL)
            player.isMuted = true
            player.actionAtItemEnd = .none
            return player
        }

        guard let playerItem = avPlayer.currentItem else {
            print("❌ Failed to create player item for Live Photo")
            return
        }

        print("   Player item status: \(playerItem.status.rawValue)")
        if let error = playerItem.error {
            print("   Player item has error: \(error.localizedDescription)")
        }

        // Check immediate status
        if playerItem.status == .readyToPlay {
            await MainActor.run {
                self.isVideoReady = true
                self.loadingError = nil
                self.loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { _ in
                    if self.isPlaying {
                        avPlayer.seek(to: .zero)
                        avPlayer.play()
                    }
                }
                self.player = avPlayer
                print("✅ Live Photo video ready (immediate)")
            }
            return
        }

        // Wait for ready state with timeout
        print("⏳ Waiting for Live Photo video to become ready...")
        let timeout: TimeInterval = 15

        await withThrowingTaskGroup(of: Void.self) { group in
            // Task 1: Watch for status changes
            group.addTask {
                for await status in playerItem.publisher(for: \.status).values {
                    print("📊 Live Photo video status: \(status.rawValue)")

                    if status == .readyToPlay {
                        await MainActor.run {
                            self.isVideoReady = true
                            self.loadingError = nil
                            self.loopObserver = NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: playerItem,
                                queue: .main
                            ) { _ in
                                if self.isPlaying {
                                    avPlayer.seek(to: .zero)
                                    avPlayer.play()
                                }
                            }
                            self.player = avPlayer
                            print("✅ Live Photo video ready")
                        }
                        return
                    } else if status == .failed {
                        if let error = playerItem.error {
                            print("❌ Live Photo video failed: \(error.localizedDescription)")
                        } else {
                            print("❌ Live Photo video failed: Unknown error")
                        }
                        await MainActor.run {
                            self.isVideoReady = false
                            self.loadingError = "Failed to load Live Photo video"
                        }
                        return
                    }
                }
            }

            // Task 2: Timeout watchdog
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                print("⏱️ Live Photo video loading timed out after \(timeout)s")
                await MainActor.run {
                    self.isVideoReady = false
                    self.loadingError = "Live Photo video timed out"
                }
            }

            // Wait for first task to complete, then cancel remaining
            try? await group.next()
            group.cancelAll()
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
