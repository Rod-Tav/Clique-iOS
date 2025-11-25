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

    /// Configure audio session category without activating
    /// Safe to call on view appear - won't interrupt other audio
    private func configureCategory() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.duckOthers]
            )
        } catch {
            logger.error("Failed to configure audio category: \(error.localizedDescription)")
        }
    }

    /// Activate audio session for actual playback
    /// Call this ONLY when user initiates audio playback (Live Photo press, video unmute)
    func activateForPlayback() {
        // Always configure - category may have been changed to .ambient by video preload
        configureCategory()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isConfigured = true
            logger.info("Audio session activated for playback")
        } catch {
            logger.error("Failed to activate audio session: \(error.localizedDescription)")
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
