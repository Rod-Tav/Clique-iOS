//
//  GestureConstants.swift
//  Clique
//
//  Created by Assistant on 9/29/25.
//

import CoreGraphics

/// Constants for gesture recognition and dismiss behavior.
///
/// These values are tuned for optimal UX across dismiss gestures in the app.
/// All dismiss gestures use consistent thresholds for predictable behavior.
enum GestureConstants {
    // MARK: - Velocity

    /// Dampening factor applied to velocity when calculating dismiss threshold.
    ///
    /// Velocity is divided by this value, contributing approximately 20% to the final
    /// dismiss calculation. This prevents overly sensitive flick dismissals while still
    /// allowing quick swipes to feel responsive.
    ///
    /// **Formula**: `finalHeight = translation.height + (velocity.height / velocityDampening)`
    ///
    /// **Used in**:
    /// - CollectionDetailView
    /// - SingleFlickView
    /// - SwipeDownToDismiss
    static let velocityDampening: CGFloat = 5

    // MARK: - Dismiss Thresholds

    /// Minimum height (in points) required to trigger dismiss when velocity is considered.
    ///
    /// This higher threshold is used when calculating dismissal with velocity contribution.
    /// It ensures that fast flicks can dismiss even with shorter drag distances.
    ///
    /// **Used in**:
    /// - CollectionDetailView (detail view dismiss)
    /// - SingleFlickView (flick image dismiss with velocity)
    static let dismissThresholdWithVelocity: CGFloat = 100

    /// Minimum height (in points) required to trigger dismiss without velocity consideration.
    ///
    /// This lower threshold is used for slower drags where velocity isn't a factor.
    /// It provides a fallback dismiss mechanism for deliberate slow swipes.
    ///
    /// **Used in**:
    /// - CollectionDetailView (iOS 17 path)
    /// - SingleFlickView (fallback dismiss)
    /// - SwipeDownToDismiss (simple dismiss)
    static let dismissThresholdBasic: CGFloat = 10

    // MARK: - Gesture Recognition

    /// Minimum distance (in points) a gesture must move before being recognized.
    ///
    /// This prevents accidental gesture triggering from small touch movements like taps.
    /// Set low enough to feel responsive but high enough to avoid false positives.
    ///
    /// **Used in**:
    /// - CompatibleDragGestureModifier
    /// - SimultaneousSwipeGesture
    static let minimumRecognitionDistance: CGFloat = 10
}