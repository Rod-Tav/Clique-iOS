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
/// IconImage("arrow-left", color: .theme.iconPrimary, size: 24)
/// 
/// // Secondary action icon
/// IconImage("settings", color: .theme.iconSecondary, size: 20)
/// 
/// // Custom colored icon
/// IconImage("heart-filled", color: .theme.pink, size: 16)
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
    
    /// Creates an icon with the specified appearance.
    ///
    /// - Parameters:
    ///   - name: The name of the icon asset in the app bundle
    ///   - color: The color to apply (prefer `.theme.iconPrimary` or `.theme.iconSecondary`)
    ///   - size: The size in points (use standard sizes: 16, 20, 24, 28)
    init(_ name: String, color: Color, size: CGFloat) {
        self.name = name
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Image(name)
            .icon(color: color, size: size)
    }
}

#Preview {
    IconImage("arrow-left", color: .theme.pink, size: 20)
}
