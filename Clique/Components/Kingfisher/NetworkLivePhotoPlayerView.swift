//
//  NetworkLivePhotoPlayerView.swift
//  Clique
//
//  Created by Assistant on Native Live Photo playback implementation.
//

import SwiftUI
import AVKit

/// Displays a Live Photo from network URLs with Apple Photos-like playback.
///
/// Replicates iOS Photos app behavior: static image with tap-and-hold video playback.
/// Since network files lack Live Photo metadata, uses custom AVPlayer with native-feeling interactions.
///
/// ## Features
/// - **Tap-and-Hold Playback**: Press to play video, release to return to still image
/// - **Smooth Transitions**: Native-feeling fade animations between layers
/// - **Background Loading**: Video preloads for instant playback
/// - **Looping**: Video loops continuously while pressed
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
    let width: CGFloat?
    let isInteractive: Bool

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isVideoReady = false
    @State private var videoOpacity: Double = 0.0
    @State private var loopObserver: NSObjectProtocol?

    // Haptic feedback generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    // Minimum hold duration to trigger live photo playback (in seconds)
    private let minimumHoldDuration: TimeInterval = 0.15

    @State private var pressTimer: Timer?
    @State private var touchStartTime: Date?
    @State private var touchStartLocation: CGPoint?

    init(imageUrl: MediaUrls?, videoUrl: MediaUrls?, quality: ImageQuality, width: CGFloat? = nil, isInteractive: Bool = true) {
        self.imageUrl = imageUrl
        self.videoUrl = videoUrl
        self.quality = quality
        self.width = width
        self.isInteractive = isInteractive
    }

    var body: some View {
        ZStack {
            // Base layer: Static image (always visible)
            // Use performance mode to avoid progressive loading issues on physical devices
            // This ensures we load the target quality directly without showing low-quality fallbacks
            if let width = width {
                // Square format for feed cells
                GenericAsyncImage(urls: imageUrl, quality: quality, performanceMode: true) { image in
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
                GenericAsyncImage(urls: imageUrl, quality: quality, performanceMode: true) { image in
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

            // Overlay layer: Video player (fades in on press)
            if let player = player {
                VideoPlayerView(player: player, shouldFill: width != nil)
                    .if(width != nil) { view in
                        view
                            .frame(width: width!, height: width!)
                            .clipped()
                    }
                    .opacity(videoOpacity)
                    .allowsHitTesting(false)
            }

            // Transparent touch handler overlay (only present when video is ready and interactive)
            if isVideoReady && isInteractive {
                if #available(iOS 26, *) {
                    // iOS 26+: Use custom gesture that works with ScrollView
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            LivePhotoInteractionGesture(
                                minimumPressDuration: minimumHoldDuration,
                                allowableMovement: 15,
                                onPressChanged: { location in
                                    // Monitor movement during press
                                    if let startLocation = touchStartLocation {
                                        let horizontalMove = abs(location.x - startLocation.x)
                                        let verticalMove = abs(location.y - startLocation.y)

                                        // Cancel if too much movement
                                        if horizontalMove > 15 || verticalMove > 20 {
                                            pressTimer?.invalidate()
                                            pressTimer = nil
                                            if isPlaying {
                                                stopPlayback()
                                            }
                                        }
                                    }
                                },
                                onPressStarted: { location in
                                    // Press started - record time, location and start timer
                                    touchStartTime = Date()
                                    touchStartLocation = location
                                    pressTimer = Timer.scheduledTimer(withTimeInterval: minimumHoldDuration, repeats: false) { _ in
                                        if !isPlaying {
                                            startPlayback()
                                        }
                                    }
                                },
                                onPressEnded: {
                                    // Press ended - cleanup
                                    pressTimer?.invalidate()
                                    pressTimer = nil
                                    touchStartTime = nil
                                    touchStartLocation = nil

                                    if isPlaying {
                                        stopPlayback()
                                    }
                                }
                            )
                        )
                } else {
                    // iOS 17-18: Use simultaneousGesture with drag to allow both tap and hold
                    Color.clear
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Check if this is a hold (not a quick tap or drag)
                                    if touchStartTime == nil {
                                        touchStartTime = Date()
                                        touchStartLocation = value.location

                                        // Start timer - if touch lasts minimum duration without movement, start playback
                                        pressTimer = Timer.scheduledTimer(withTimeInterval: minimumHoldDuration, repeats: false) { _ in
                                            if !isPlaying {
                                                startPlayback()
                                            }
                                        }
                                    }

                                    // Cancel if too much movement (user is scrolling/paging)
                                    if let startLocation = touchStartLocation {
                                        let horizontalMove = abs(value.translation.width)
                                        let verticalMove = abs(value.translation.height)

                                        if horizontalMove > 15 || verticalMove > 20 {
                                            pressTimer?.invalidate()
                                            pressTimer = nil
                                            if isPlaying {
                                                stopPlayback()
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // Touch ended - cleanup
                                    pressTimer?.invalidate()
                                    pressTimer = nil
                                    touchStartTime = nil
                                    touchStartLocation = nil

                                    if isPlaying {
                                        stopPlayback()
                                    }
                                }
                        )
                }
            }
        }
        .task {
            // Only preload video if interactive (to save bandwidth)
            if isInteractive {
                await preloadVideo()
            }
        }
        .onDisappear {
            cleanup()
        }
    }

    private func handleTouchChanged(location: CGPoint, translation: CGSize) {
        // First touch - record start time and location
        if touchStartTime == nil {
            touchStartTime = Date()
            touchStartLocation = location

            // Start timer to trigger playback after 0.05s
            pressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                if !isPlaying {
                    startPlayback()
                }
            }
        }

        // Check if user has moved significantly (scrolling/paging)
        let horizontalMove = abs(translation.width)
        let verticalMove = abs(translation.height)

        // Cancel playback if too much movement
        if horizontalMove > 15 || verticalMove > 20 {
            pressTimer?.invalidate()
            pressTimer = nil
            if isPlaying {
                stopPlayback()
            }
        }
    }

    private func handleTouchEnded() {
        // Clean up
        pressTimer?.invalidate()
        pressTimer = nil
        touchStartTime = nil

        // Stop playback if active
        if isPlaying {
            stopPlayback()
        }
    }

    /// Preload video in background for instant playback
    private func preloadVideo() async {
        guard let videoURL = videoUrl?.videoUrl(for: quality) else { return }

        // Create player with network URL for streaming
        // AVPlayer handles preloading and caching automatically
        await MainActor.run {
            let avPlayer = AVPlayer(url: videoURL)
            avPlayer.isMuted = true
            avPlayer.actionAtItemEnd = .none

            // Setup looping
            if let playerItem = avPlayer.currentItem {
                loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { [weak avPlayer] _ in
                    avPlayer?.seek(to: .zero)
                    if self.isPlaying {
                        avPlayer?.play()
                    }
                }
            }

            player = avPlayer
            isVideoReady = true
        }
    }

    /// Start playback with native-feeling transition
    private func startPlayback() {
        guard let player = player, !isPlaying else { return }

        isPlaying = true
        player.seek(to: .zero)

        // Haptic feedback like Apple Photos
        impactFeedback.impactOccurred()

        // Quick fade-in for instant feel
        withAnimation(.easeOut(duration: 0.1)) {
            videoOpacity = 1.0
        }

        player.play()
    }

    /// Stop playback and return to still image
    private func stopPlayback() {
        guard let player = player, isPlaying else { return }

        isPlaying = false

        // Quick fade-out
        withAnimation(.easeIn(duration: 0.1)) {
            videoOpacity = 0.0
        }

        player.pause()
        player.seek(to: .zero)
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
    NetworkLivePhotoPlayerView(
        imageUrl: nil,
        videoUrl: nil,
        quality: .high
    )
}
