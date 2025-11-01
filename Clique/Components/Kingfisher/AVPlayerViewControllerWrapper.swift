//
//  AVPlayerViewControllerWrapper.swift
//  Clique
//
//  Created by Assistant on Video playback implementation.
//

import SwiftUI
import AVKit

/// Reusable SwiftUI wrapper for AVPlayerViewController with native controls.
///
/// Provides a consistent video playback experience across the app with:
/// - Native iOS playback controls (play/pause, scrubber, volume, fullscreen)
/// - Picture-in-Picture support
/// - Automatic appearance adaptation
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
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}
