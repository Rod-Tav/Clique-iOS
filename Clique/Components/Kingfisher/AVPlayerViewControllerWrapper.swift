//
//  AVPlayerViewControllerWrapper.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit
import Combine

/// Reusable SwiftUI wrapper for AVPlayerViewController with native controls.
///
/// Provides a consistent video playback experience across the app with:
/// - Native iOS playback controls (play/pause, scrubber, volume, fullscreen)
/// - Picture-in-Picture support
/// - Transparent background (shows parent view background)
/// - Automatic audio pause during scrubbing for best UX
///
/// ## Scrubbing Behavior
/// When the user scrubs through the video using the native slider, the audio automatically
/// pauses to prevent audio from continuing to play at the old position. Audio resumes
/// when scrubbing ends.
///
/// ## Usage
/// ```swift
/// AVPlayerViewControllerWrapper(player: avPlayer)
/// ```
struct AVPlayerViewControllerWrapper: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true

        // Use transparent background to let parent view background show through
        controller.view.backgroundColor = .clear

        // Set up scrubbing observation
        context.coordinator.setupObservation(for: player)

        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        // Only update player if it changed
        if controller.player !== player {
            controller.player = player
            context.coordinator.setupObservation(for: player)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Coordinator that observes player state to handle scrubbing
    class Coordinator {
        private var timeControlStatusObserver: AnyCancellable?
        private var rateObserver: AnyCancellable?
        private var isScrubbing = false
        private var muteStateBeforeScrub = false
        private var hasStartedPlaying = false

        func setupObservation(for player: AVPlayer) {
            // Clean up existing observers
            timeControlStatusObserver?.cancel()
            rateObserver?.cancel()
            hasStartedPlaying = false

            // Observe timeControlStatus to detect scrubbing state
            timeControlStatusObserver = player.publisher(for: \.timeControlStatus)
                .sink { [weak self] status in
                    self?.handleTimeControlStatusChange(status, player: player)
                }

            // Observe rate changes as a secondary indicator
            rateObserver = player.publisher(for: \.rate)
                .sink { [weak self] rate in
                    self?.handleRateChange(rate, player: player)
                }
        }

        private func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus, player: AVPlayer) {
            // Track when video has actually started playing (to avoid false positives on load)
            if status == .playing {
                hasStartedPlaying = true
            }

            switch status {
            case .waitingToPlayAtSpecifiedRate:
                // Only treat as scrubbing if:
                // 1. Video has started playing (not initial load)
                // 2. Rate is 0 (not just buffering)
                // 3. Not already scrubbing
                if hasStartedPlaying && player.rate == 0 && !isScrubbing {
                    startScrubbing(player: player)
                }

            case .playing:
                // Playback resumed after scrubbing
                if isScrubbing {
                    endScrubbing(player: player)
                }

            case .paused:
                // User manually paused or scrubbing ended with pause
                if isScrubbing {
                    endScrubbing(player: player)
                }

            @unknown default:
                break
            }
        }

        private func handleRateChange(_ rate: Float, player: AVPlayer) {
            // Only consider rate changes after video has started playing
            guard hasStartedPlaying else { return }

            let currentTime = player.currentTime().seconds
            let duration = player.currentItem?.duration.seconds ?? 0

            // When rate becomes 0 and we're not at the end, user might be scrubbing
            if rate == 0 {
                // If not at the end and rate is 0, we might be scrubbing
                if duration > 0 && currentTime < duration - 0.5 && !isScrubbing {
                    // Check if this is a scrubbing pause (not a manual pause)
                    // by verifying timeControlStatus
                    if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                        startScrubbing(player: player)
                    }
                }
            } else if rate > 0 && isScrubbing {
                // Playback resumed while we thought we were scrubbing
                endScrubbing(player: player)
            }
        }

        private func startScrubbing(player: AVPlayer) {
            guard !isScrubbing else { return }

            isScrubbing = true
            // Store current mute state and mute the player
            muteStateBeforeScrub = player.isMuted
            player.isMuted = true
        }

        private func endScrubbing(player: AVPlayer) {
            guard isScrubbing else { return }

            isScrubbing = false
            // Restore previous mute state
            player.isMuted = muteStateBeforeScrub
        }

        deinit {
            timeControlStatusObserver?.cancel()
            rateObserver?.cancel()
        }
    }
}
