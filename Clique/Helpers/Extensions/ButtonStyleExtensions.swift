//
//  ButtonStyleExtensions.swift
//  Clique
//
//  Created by Rod Tavangar on 1/28/25.
//

import SwiftUI

struct NoHighlightButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}
 
extension ButtonStyle where Self == NoHighlightButtonStyle {
  static var noHighlight: NoHighlightButtonStyle {
    get { NoHighlightButtonStyle() }
  }
}

/// A button style that provides a satisfying bounce animation on press
struct BounceButtonStyle: ButtonStyle {
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension ButtonStyle where Self == BounceButtonStyle {
    static var bounce: BounceButtonStyle {
        get { BounceButtonStyle() }
    }
}

extension Button {
    func noHighlight() -> some View {
        self
            .buttonStyle(.noHighlight)
    }
    
    func bounce() -> some View {
        self
            .buttonStyle(.bounce)
    }
}

extension NavigationLink {
    func noHighlight() -> some View {
        self
            .buttonStyle(.noHighlight)
    }
    
    func bounce() -> some View {
        self
            .buttonStyle(.bounce)
    }
}
