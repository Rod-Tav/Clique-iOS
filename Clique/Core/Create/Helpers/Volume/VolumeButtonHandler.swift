//
//  VolumeButtonHandler.swift
//  Clique
//
//  Created by Rod Tavangar on 3/12/25.
//

import SwiftUI
import AVFoundation
import MediaPlayer

/// Observable object to detect volume button presses and reset system volume.
class VolumeButtonHandler: NSObject, ObservableObject {
    private var initialVolume: Float = 0.5
    private var volumeView: MPVolumeView!
    private var isResettingVolume = false
    
    /// Public callbacks for button presses
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onAnyVolumePress: (() -> Void)?
    var shouldHandlePress: (() -> Bool)?
    
    override init() {
        super.init()
        setupVolumeHandling()
    }
    
    /// Setup audio session to observe volume changes and prepare MPVolumeView to reset system volume.
    private func setupVolumeHandling() {
        // Setup MPVolumeView (hidden) to allow programmatically resetting system volume
        volumeView = MPVolumeView(frame: .zero)
        volumeView.isHidden = true
        UIWindow.current?.addSubview(volumeView) // Required to make MPVolumeView work for setting volume
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Activate audio session to listen to volume button presses
            try audioSession.setCategory(.playback, options: [.mixWithOthers]) // MixWithOthers allows music to keep playing
            try audioSession.setActive(true)
            initialVolume = audioSession.outputVolume // Store initial system volume
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // Observe volume changes
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: [.old, .new], context: nil)
    }
    
    deinit {
        // Cleanup observer and MPVolumeView when done
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        volumeView.removeFromSuperview()
    }
    
    /// Observe system volume changes and detect button presses.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "outputVolume" else { return }
        
        if isResettingVolume {
            // Skip volume changes triggered by self-reset
            return
        }
        
        if let newVolume = change?[.newKey] as? Float,
           let oldVolume = change?[.oldKey] as? Float,
           newVolume != oldVolume {
            DispatchQueue.main.async {
                self.handleVolumeButtonPress(newVolume: newVolume, oldVolume: oldVolume)
            }
        }
    }
    
    /// Handle volume button press and reset volume after a small delay.
    private func handleVolumeButtonPress(newVolume: Float, oldVolume: Float) {
        // ✅ Check if we should handle this press
        if let shouldHandlePress = shouldHandlePress, !shouldHandlePress() {
            return
        }
        
        if newVolume > oldVolume {
            onVolumeUp?()
        } else if newVolume < oldVolume {
            onVolumeDown?()
        }
        
        // Call unified handler for any button press
        onAnyVolumePress?()
        
        // ✅ Delay volume reset slightly to avoid double firing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setSystemVolume(self.initialVolume)
        }
    }
    
    /// Programmatically reset system volume using MPVolumeView slider.
    private func setSystemVolume(_ volume: Float) {
        isResettingVolume = true
        guard let volumeSlider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else { return }
        volumeSlider.setValue(volume, animated: false)
        
        // Reset flag after slight delay to avoid triggering self-induced events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isResettingVolume = false
        }
    }
}
