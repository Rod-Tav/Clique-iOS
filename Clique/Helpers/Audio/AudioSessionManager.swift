//
//  AudioSessionManager.swift
//  Clique
//
//  Manages AVAudioSession configuration for Live Photo playback
//

import AVFoundation
import OSLog

/// Manages audio session configuration for the app
/// Configures audio to play even when device is in silent mode
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private let logger = Logger(subsystem: "com.clique", category: "AudioSession")
    private var isConfigured = false

    private init() {}

    /// Configure audio session for Live Photo playback
    /// Uses .playback category to ignore silent mode
    func configureLivePhotoAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Always set category and mode to ensure proper configuration
            // Use .playback category to ignore silent mode
            // Use .moviePlayback mode for video with audio
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.mixWithOthers, .duckOthers]
            )

            // Always activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            logger.info("Audio session configured and activated for Live Photo playback")
            isConfigured = true
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Deactivate audio session when no longer needed
    func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
