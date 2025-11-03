//
//  IconImage.swift
//  Clique
//
//  Created by Rod Tavangar on 1/13/25.
//

import SwiftUI

/// A reusable icon component that displays app icons with consistent styling.
///
/// This component provides a standardized way to display icons throughout the app
/// with proper theming support and consistent sizing. It automatically applies
/// the app's icon styling modifier for uniform appearance.
///
/// ## Design System Integration
/// This component is part of the app's design system and should be used for
/// all icon displays to maintain visual consistency. It integrates with the
/// theme system and supports both light and dark modes.
///
/// ## Usage
/// ```swift
/// // Primary navigation icon
/// IconImage(name: "arrow-left", color: .theme.iconPrimary, size: 24)
/// 
/// // Secondary action icon
/// IconImage(name: "settings", color: .theme.iconSecondary, size: 20)
/// 
/// // Custom colored icon
/// IconImage(name: "heart-filled", color: .theme.pink, size: 16)
/// ```
///
/// ## Best Practices
/// - Always use semantic colors from the theme system (e.g., `.theme.iconPrimary`)
/// - Use standard sizes: 16, 20, 24, 28 for consistency
/// - Prefer this component over raw `Image` for icons
/// - Icon names should match assets in the app bundle
///
/// - Important: Icon assets must exist in the app bundle
/// - Note: Automatically adapts to light/dark mode when using theme colors
struct IconImage: View {
    /// Name of the icon asset to display
    let name: String
    /// Color to apply to the icon (use theme colors for consistency)
    let color: Color
    /// Size of the icon in points
    let size: CGFloat
    
    var body: some View {
        Image(name)
            .icon(color: color, size: size)
    }
}

#Preview {
    IconImage(name: "arrow-left", color: .theme.pink, size: 20)
}
