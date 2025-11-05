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
/// ## iOS 26+ Behavior
/// Uses `SimultaneousSwipeGesture` (UIGestureRecognizerRepresentable) which:
/// - Properly cleans up gesture recognizers on view dismissal
/// - Tracks gesture activity state to prevent interference with other gestures
/// - Selectively allows simultaneous recognition based on gesture state
///
/// ## iOS 17-18 Behavior
/// Uses standard SwiftUI `simultaneousGesture` with `DragGesture`
///
/// Reference: FB18199844
struct CompatibleDragGestureModifier: ViewModifier {
    let minimumDistance: CGFloat
    let onChanged: ((CGSize) -> Void)?
    let onEnded: ((CGSize, CGSize) -> Void)?  // (translation, velocity)

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // Use UIGestureRecognizerRepresentable workaround for iOS 26+
            // This approach properly handles gesture cleanup and prevents UI freezing
            // when dismissing fullScreenCover presentations
            content
                .gesture(
                    SimultaneousSwipeGesture(
                        minimumDistance: minimumDistance,
                        onChanged: { translation in
                            onChanged?(translation)
                        },
                        onEnded: { translation, velocity in
                            onEnded?(translation, velocity)
                        }
                    )
                )
        } else {
            // Use standard simultaneousGesture for iOS 17-18
            let gesture = DragGesture(minimumDistance: minimumDistance)
                .onChanged { value in
                    onChanged?(value.translation)
                }
                .onEnded { value in
                    // Calculate velocity approximation for consistency
                    // DragGesture doesn't provide velocity directly, so we approximate
                    let velocity = CGSize(width: value.predictedEndTranslation.width - value.translation.width,
                                         height: value.predictedEndTranslation.height - value.translation.height)
                    onEnded?(value.translation, velocity)
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
        onEnded: ((CGSize, CGSize) -> Void)? = nil  // (translation, velocity)
    ) -> some View {
        modifier(CompatibleDragGestureModifier(
            minimumDistance: minimumDistance,
            onChanged: onChanged,
            onEnded: onEnded
        ))
    }
}