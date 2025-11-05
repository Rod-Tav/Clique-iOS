//
//  SimultaneousSwipeGesture.swift
//  Clique
//
//  Created by Assistant on 3/22/25.
//

import SwiftUI
import UIKit

/// A UIGestureRecognizerRepresentable that works with ScrollView on iOS 26.
/// This is a workaround for FB18199844 where simultaneousGesture with DragGesture
/// breaks ScrollView scrolling in iOS 26.
///
/// ## Key Features
/// - Tracks gesture activity state to prevent interference with other gestures
/// - Properly cleans up gesture recognizers to prevent UI freezing after view dismissal
/// - Selectively allows simultaneous recognition only when gesture is active
/// - Resets translation state to maintain clean gesture state
struct SimultaneousSwipeGesture: UIGestureRecognizerRepresentable {
    let minimumDistance: CGFloat
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, CGSize) -> Void  // (translation, velocity)

    init(
        minimumDistance: CGFloat = 10,
        onChanged: @escaping (CGSize) -> Void = { _ in },
        onEnded: @escaping (CGSize, CGSize) -> Void
    ) {
        self.minimumDistance = minimumDistance
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gestureRecognizer = UIPanGestureRecognizer()
        gestureRecognizer.delegate = context.coordinator
        return gestureRecognizer
    }

    func handleUIGestureRecognizerAction(_ gestureRecognizer: UIPanGestureRecognizer, context: Context) {
        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
        let translationSize = CGSize(width: translation.x, height: translation.y)

        switch gestureRecognizer.state {
        case .began:
            context.coordinator.initialLocation = translation
            context.coordinator.isActive = true
        case .changed:
            // Only process if gesture is still active
            guard context.coordinator.isActive else { return }

            // Check if we've moved enough to trigger
            let distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
            if distance >= minimumDistance {
                onChanged(translationSize)
            }
        case .ended, .cancelled:
            defer { context.coordinator.isActive = false }

            let distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
            if distance >= minimumDistance {
                // Capture velocity for flick detection
                let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
                let velocitySize = CGSize(width: velocity.x, height: velocity.y)
                onEnded(translationSize, velocitySize)
            }
        case .failed:
            context.coordinator.isActive = false
        default:
            break
        }
    }

    func updateUIGestureRecognizer(_ gestureRecognizer: UIPanGestureRecognizer, context: Context) {
        // Reset gesture state when view updates
        // This helps prevent stale gesture recognizers from blocking touch input
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            // Don't interrupt active gestures
            return
        }

        // Reset translation for clean state
        gestureRecognizer.setTranslation(.zero, in: gestureRecognizer.view)
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var initialLocation: CGPoint = .zero
        var isActive: Bool = false

        // Critical: Allow simultaneous recognition with ScrollView
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Only allow simultaneous recognition if this gesture is active or beginning
            // This prevents interference with other gestures when view is being dismissed
            guard isActive || gestureRecognizer.state == .possible || gestureRecognizer.state == .began else {
                return false
            }

            // Allow simultaneous recognition with scroll view pan gesture
            return otherGestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}