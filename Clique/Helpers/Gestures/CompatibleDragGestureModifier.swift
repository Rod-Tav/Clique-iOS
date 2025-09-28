//
//  CompatibleDragGestureModifier.swift
//  Clique
//
//  Created by Assistant on 3/22/25.
//

import SwiftUI

/// A view modifier that applies DragGesture in a ScrollView-compatible way.
///
/// Works around a bug where simultaneousGesture with DragGesture blocks ScrollView scrolling
/// on certain iOS versions by using UIGestureRecognizerRepresentable when needed.
///
/// Reference: FB18199844
struct CompatibleDragGestureModifier: ViewModifier {
    let minimumDistance: CGFloat
    let onChanged: ((CGSize) -> Void)?
    let onEnded: ((CGSize) -> Void)?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // Use UIGestureRecognizerRepresentable workaround for newer iOS
            content
                .gesture(
                    SimultaneousSwipeGesture(
                        minimumDistance: minimumDistance,
                        onChanged: { translation in
                            onChanged?(translation)
                        },
                        onEnded: { translation in
                            onEnded?(translation)
                        }
                    )
                )
        } else {
            // Use standard simultaneousGesture for older iOS
            let gesture = DragGesture(minimumDistance: minimumDistance)
                .onChanged { value in
                    onChanged?(value.translation)
                }
                .onEnded { value in
                    onEnded?(value.translation)
                }

            content
                .simultaneousGesture(gesture)
        }
    }
}

extension View {
    /// Applies a DragGesture that works properly with ScrollView across all iOS versions.
    ///
    /// Use this for swipe gestures on content inside a ScrollView.
    ///
    /// Example:
    /// ```swift
    /// ScrollView {
    ///     Image("photo")
    ///         .compatibleDragGesture(
    ///             minimumDistance: 10,
    ///             onEnded: { translation in
    ///                 if translation.height < -50 {
    ///                     // Handle swipe up
    ///                 }
    ///             }
    ///         )
    /// }
    /// ```
    func compatibleDragGesture(
        minimumDistance: CGFloat = 10,
        onChanged: ((CGSize) -> Void)? = nil,
        onEnded: ((CGSize) -> Void)? = nil
    ) -> some View {
        modifier(CompatibleDragGestureModifier(
            minimumDistance: minimumDistance,
            onChanged: onChanged,
            onEnded: onEnded
        ))
    }
}