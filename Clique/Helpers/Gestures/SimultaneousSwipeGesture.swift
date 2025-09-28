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
struct SimultaneousSwipeGesture: UIGestureRecognizerRepresentable {
    let minimumDistance: CGFloat
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void

    init(
        minimumDistance: CGFloat = 10,
        onChanged: @escaping (CGSize) -> Void = { _ in },
        onEnded: @escaping (CGSize) -> Void
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
        case .changed:
            // Check if we've moved enough to trigger
            let distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
            if distance >= minimumDistance {
                onChanged(translationSize)
            }
        case .ended, .cancelled:
            let distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
            if distance >= minimumDistance {
                onEnded(translationSize)
            }
        default:
            break
        }
    }

    func updateUIGestureRecognizer(_ gestureRecognizer: UIPanGestureRecognizer, context: Context) {
        // No updates needed
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var initialLocation: CGPoint = .zero

        // Critical: Allow simultaneous recognition with ScrollView
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition with scroll view pan gesture
            return otherGestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}