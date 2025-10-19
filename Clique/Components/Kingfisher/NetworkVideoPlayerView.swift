//
//  NetworkVideoPlayerView.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit

/// Displays a standalone video from network URLs with auto-play looping.
///
/// Replicates modern video feed experiences (Instagram/TikTok): auto-plays muted video
/// in a loop. Tap to toggle play/pause with visual feedback.
///
/// ## Features
/// - **Auto-Play**: Starts playing automatically when view appears
/// - **Looping**: Video loops continuously
/// - **Muted**: Plays without sound by default
/// - **Tap to Pause**: Tap anywhere to pause/resume
/// - **Play/Pause Icon**: Visual feedback overlay
/// - **Background Preloading**: Video loads immediately for instant playback
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

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isVideoReady = false
    @State private var loopObserver: NSObjectProtocol?
    @State private var showPlayPauseIcon = false
    @State private var loadingError: String? = nil
    @State private var isRetrying = false

    var body: some View {
        ZStack {
            // Base layer: Video player or thumbnail
            if let player = player {
                VideoPlayerView(player: player)
                    .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                    .onTapGesture {
                        togglePlayPause()
                    }
            } else {
                // Fallback: Show thumbnail while video loads
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

            // Error overlay
            if let errorMessage = loadingError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        isRetrying = true
                        loadingError = nil
                        Task {
                            await preloadAndPlayVideo()
                            isRetrying = false
                        }
                    } label: {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Retry")
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRetrying)
                }
                .frame(maxWidth: .infinity)
                .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                .background(Color.black.opacity(0.7))
            }

            // Play/Pause icon overlay
            if showPlayPauseIcon {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .transition(.opacity)
            }
        }
        .task {
            await preloadAndPlayVideo()
        }
        .onDisappear {
            cleanup()
        }
    }

    /// Preload video and auto-play
    private func preloadAndPlayVideo() async {
        guard let videoURL = videoUrl?.videoUrl(for: quality) else {
            print("⚠️ No video URL for video playback")
            print("   videoUrl: \(String(describing: videoUrl))")
            print("   quality: \(quality)")
            return
        }

        print("🔄 Downloading and caching video: \(videoURL.lastPathComponent)")
        print("   S3 URL: \(videoURL.absoluteString)")

        // Download and cache video with .mp4 extension
        let cachedURL: URL
        do {
            cachedURL = try await VideoCache.shared.getVideo(from: videoURL)
        } catch {
            print("❌ Failed to cache video: \(error.localizedDescription)")
            await MainActor.run {
                self.loadingError = "Failed to download video\n\(error.localizedDescription)"
            }
            return
        }

        // Configure audio session before creating player
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error.localizedDescription)")
        }

        // Create AVPlayer with cached local file
        let avPlayer = await MainActor.run {
            let player = AVPlayer(url: cachedURL)
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.automaticallyWaitsToMinimizeStalling = false
            return player
        }

        guard let playerItem = avPlayer.currentItem else {
            print("❌ Failed to create player item for video")
            return
        }

        // Check immediate status
        if playerItem.status == .readyToPlay {
            await MainActor.run {
                self.player = avPlayer
                self.isVideoReady = true
                setupLoopObserver(for: playerItem, player: avPlayer)
                autoPlay()
                print("✅ Video ready and playing (immediate)")
            }
            return
        }

        // Wait for ready state with timeout
        print("⏳ Waiting for video to become ready...")
        let timeout: TimeInterval = 15 // 15 second timeout

        await withThrowingTaskGroup(of: Void.self) { group in
            // Task 1: Watch for status changes
            group.addTask {
                for await status in playerItem.publisher(for: \.status).values {
                    print("📊 Video status changed to: \(status.rawValue)")

                    if status == .readyToPlay {
                        await MainActor.run {
                            self.player = avPlayer
                            self.isVideoReady = true
                            self.loadingError = nil
                            setupLoopObserver(for: playerItem, player: avPlayer)
                            autoPlay()
                            print("✅ Video ready and playing")
                        }
                        return
                    } else if status == .failed {
                        let errorMessage: String
                        if let error = playerItem.error {
                            print("❌ Video failed to load: \(error.localizedDescription)")
                            // Check if it's a network error
                            let nsError = error as NSError
                            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                                errorMessage = "Video failed to load\nNetwork timeout"
                            } else {
                                errorMessage = "Video failed to load\n\(error.localizedDescription)"
                            }
                        } else {
                            print("❌ Video failed to load: Unknown error")
                            errorMessage = "Video failed to load\nUnknown error"
                        }

                        await MainActor.run {
                            self.loadingError = errorMessage
                            self.player = nil
                        }
                        return
                    }
                }
            }

            // Task 2: Timeout watchdog
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                print("⏱️ Video loading timed out after \(timeout)s")
                await MainActor.run {
                    self.loadingError = "Video loading timed out\nPlease check your connection"
                    self.player = nil
                }
            }

            // Wait for first task to complete, then cancel remaining
            try? await group.next()
            group.cancelAll()
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
            if self.isPlaying {
                player.play()
            }
        }
    }

    /// Auto-play video when ready
    private func autoPlay() {
        guard let player = player, isVideoReady else { return }

        isPlaying = true
        player.play()
        print("▶️ Video auto-play started")
    }

    /// Toggle play/pause
    private func togglePlayPause() {
        guard let player = player, isVideoReady else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            print("⏸ Video paused")
        } else {
            player.play()
            isPlaying = true
            print("▶️ Video resumed")
        }

        // Show icon briefly
        showPlayPauseIcon = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                showPlayPauseIcon = false
            }
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

    /// Convert FourCC codec code to readable string
    private func fourCCToString(_ fourCC: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((fourCC >> 24) & 0xff),
            CChar((fourCC >> 16) & 0xff),
            CChar((fourCC >> 8) & 0xff),
            CChar(fourCC & 0xff),
            0
        ]
        return String(cString: bytes)
    }
}

#Preview {
    NetworkVideoPlayerView(
        thumbnailUrl: nil,
        videoUrl: nil,
        quality: .high
    )
}
