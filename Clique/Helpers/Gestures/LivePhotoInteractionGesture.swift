//
//  LivePhotoInteractionGesture.swift
//  Clique
//
//  Created by Assistant on iOS 26 live photo gesture fix.
//

import SwiftUI
import UIKit

/// A UIGestureRecognizerRepresentable for live photo tap-and-hold interaction on iOS 26.
///
/// This gesture works seamlessly with horizontal ScrollView scrolling by:
/// - Using UILongPressGestureRecognizer for press-and-hold detection
/// - Monitoring touch movement to cancel if user is scrolling/paging
/// - Allowing simultaneous recognition with scroll gestures
/// - Failing gracefully when horizontal movement exceeds threshold
///
/// ## Usage
/// ```swift
/// Color.clear
///     .contentShape(.rect)
///     .gesture(
///         LivePhotoInteractionGesture(
///             minimumPressDuration: 0.05,
///             onPressStarted: { startPlayback() },
///             onPressEnded: { stopPlayback() }
///         )
///     )
/// ```
struct LivePhotoInteractionGesture: UIGestureRecognizerRepresentable {
    let minimumPressDuration: TimeInterval
    let allowableMovement: CGFloat
    let onPressChanged: (CGPoint) -> Void
    let onPressStarted: (CGPoint) -> Void
    let onPressEnded: () -> Void

    init(
        minimumPressDuration: TimeInterval = 0.05,
        allowableMovement: CGFloat = 15,
        onPressChanged: @escaping (CGPoint) -> Void = { _ in },
        onPressStarted: @escaping (CGPoint) -> Void,
        onPressEnded: @escaping () -> Void
    ) {
        self.minimumPressDuration = minimumPressDuration
        self.allowableMovement = allowableMovement
        self.onPressChanged = onPressChanged
        self.onPressStarted = onPressStarted
        self.onPressEnded = onPressEnded
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let gestureRecognizer = MovementTrackingLongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleGesture(_:))
        )
        gestureRecognizer.minimumPressDuration = minimumPressDuration
        gestureRecognizer.allowableMovement = allowableMovement
        gestureRecognizer.delegate = context.coordinator
        context.coordinator.gestureRecognizer = gestureRecognizer
        return gestureRecognizer
    }

    func handleUIGestureRecognizerAction(_ gestureRecognizer: UILongPressGestureRecognizer, context: Context) {
        // Handled via target-action in coordinator
    }

    func updateUIGestureRecognizer(_ gestureRecognizer: UILongPressGestureRecognizer, context: Context) {
        gestureRecognizer.minimumPressDuration = minimumPressDuration
        if let movementTrackingGR = gestureRecognizer as? MovementTrackingLongPressGestureRecognizer {
            movementTrackingGR.horizontalMovementThreshold = allowableMovement
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(
            onPressChanged: onPressChanged,
            onPressStarted: onPressStarted,
            onPressEnded: onPressEnded
        )
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onPressChanged: (CGPoint) -> Void
        let onPressStarted: (CGPoint) -> Void
        let onPressEnded: () -> Void
        weak var gestureRecognizer: UILongPressGestureRecognizer?
        var isActive: Bool = false

        init(
            onPressChanged: @escaping (CGPoint) -> Void,
            onPressStarted: @escaping (CGPoint) -> Void,
            onPressEnded: @escaping () -> Void
        ) {
            self.onPressChanged = onPressChanged
            self.onPressStarted = onPressStarted
            self.onPressEnded = onPressEnded
        }

        @objc func handleGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
            switch gestureRecognizer.state {
            case .began:
                isActive = true
                if let view = gestureRecognizer.view {
                    let location = gestureRecognizer.location(in: view)
                    onPressStarted(location)
                }
            case .changed:
                if isActive, let view = gestureRecognizer.view {
                    let location = gestureRecognizer.location(in: view)
                    onPressChanged(location)
                }
            case .ended, .cancelled, .failed:
                if isActive {
                    onPressEnded()
                }
                isActive = false
            default:
                break
            }
        }

        // Allow simultaneous recognition with ScrollView's pan gesture
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Allow simultaneous recognition with scroll view pan gestures
            return otherGestureRecognizer is UIPanGestureRecognizer
        }

        // This gesture should be allowed to begin
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

/// Custom UILongPressGestureRecognizer that tracks movement and fails if horizontal movement exceeds threshold
private class MovementTrackingLongPressGestureRecognizer: UILongPressGestureRecognizer {
    var horizontalMovementThreshold: CGFloat = 15
    private var initialLocation: CGPoint = .zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let touch = touches.first, let view = self.view {
            initialLocation = touch.location(in: view)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        // Check horizontal movement - if exceeds threshold, fail this gesture to let ScrollView take over
        if let touch = touches.first, let view = self.view {
            let currentLocation = touch.location(in: view)
            let horizontalMovement = abs(currentLocation.x - initialLocation.x)
            let verticalMovement = abs(currentLocation.y - initialLocation.y)

            // Fail if significant horizontal movement (user is scrolling)
            // Allow more vertical movement since user might be scrolling vertically or just holding
            if horizontalMovement > horizontalMovementThreshold && horizontalMovement > verticalMovement {
                self.state = .failed
            }
        }
    }
}
