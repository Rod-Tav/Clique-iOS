//
//  View+LoadWhenVisible.swift
//  Clique
//
//  Created by Assistant on visibility-based loading refactoring.
//

import SwiftUI

/// View modifier that manages content loading based on visibility state.
///
/// This modifier eliminates code duplication across image/video loaders by centralizing
/// the common pattern of loading content when visible and canceling when not visible.
///
/// ## Usage
/// ```swift
/// view
///     .loadWhenVisible(
///         isVisible: isVisible,
///         onLoad: { loadContent() },
///         onCancel: { cancelLoading() }
///     )
/// ```
struct LoadWhenVisibleModifier: ViewModifier {
    let isVisible: Bool
    let onLoad: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isVisible) { _, newValue in
                if newValue {
                    onLoad()
                } else {
                    onCancel()
                }
            }
            .onAppear {
                if isVisible {
                    onLoad()
                }
            }
            .onDisappear {
                onCancel()
            }
    }
}

extension View {
    /// Loads content when the view becomes visible and cancels loading when not visible.
    ///
    /// - Parameters:
    ///   - isVisible: Whether this content should currently be loaded
    ///   - onLoad: Closure to execute when becoming visible or on appear if already visible
    ///   - onCancel: Closure to execute when becoming not visible or on disappear
    /// - Returns: Modified view with visibility-based loading behavior
    func loadWhenVisible(
        isVisible: Bool,
        onLoad: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(LoadWhenVisibleModifier(
            isVisible: isVisible,
            onLoad: onLoad,
            onCancel: onCancel
        ))
    }
}
