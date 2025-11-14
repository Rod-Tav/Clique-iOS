//
//  SwipeDownToDismiss.swift
//  Clique
//
//  Created by Rod Tavangar on 7/10/25.
//

import SwiftUI

struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    var isZoomed: Binding<Bool>?
    @State private var dismissOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(dismissOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: GestureConstants.minimumRecognitionDistance)
                    .onChanged { value in
                        guard isZoomed?.wrappedValue != true else { return }
                        guard value.translation.height > GestureConstants.minimumVerticalSwipe && abs(value.translation.width) < GestureConstants.maximumHorizontalDeviation else { return }
                        dismissOffset = CGSize(width: 0, height: value.translation.height)
                    }
                    .onEnded { value in
                        let height = value.translation.height + (value.velocity.height / GestureConstants.velocityDampening)
                        if height > GestureConstants.dismissThresholdBasic {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissOffset = .zero
                            }
                        }
                    }
            )
    }
}

extension View {
    func swipeDownToDismiss(isZoomed: Binding<Bool>? = nil) -> some View {
        self.modifier(SwipeToDismissModifier(isZoomed: isZoomed))
    }
}

struct SwipeToDismissWithBindingModifier: ViewModifier {
    @Binding var isPresented: Bool
    var isSwiping: Binding<Bool>?
    var isZoomed: Binding<Bool>?

    @State private var dismissOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: dismissOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: GestureConstants.minimumRecognitionDistance)
                    .onChanged { value in
                        guard isZoomed?.wrappedValue != true else { return }
                        guard abs(value.translation.width) < GestureConstants.maximumHorizontalDeviation else { return }
                        // Only allow downward movement - clamp at 0 to prevent upward drift
                        dismissOffset = max(0, value.translation.height)
                        // Notify that swiping has started
                        isSwiping?.wrappedValue = true
                    }
                    .onEnded { value in
                        let height = value.translation.height + (value.velocity.height / GestureConstants.velocityDampening)
                        if height > GestureConstants.dismissThresholdBasic {
                            // Animate off screen then dismiss
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismissOffset = UIScreen.main.bounds.height
                            }
                            // Delay setting binding to false until animation completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isPresented = false
                                dismissOffset = 0 // Reset for next appearance
                                isSwiping?.wrappedValue = false
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissOffset = 0
                            }
                            // Reset swiping state immediately if swipe was cancelled
                            isSwiping?.wrappedValue = false
                        }
                    }
            )
    }
}

extension View {
    func swipeDownToDismiss(isPresented: Binding<Bool>, isSwiping: Binding<Bool>? = nil, isZoomed: Binding<Bool>? = nil) -> some View {
        self.modifier(SwipeToDismissWithBindingModifier(isPresented: isPresented, isSwiping: isSwiping, isZoomed: isZoomed))
    }
}
