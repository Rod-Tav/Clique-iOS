//
//  DoubleTapLikeModifier.swift
//  Clique
//
//  Created by Rod Tavangar on 2/17/25.
//

import SwiftUI

struct DoubleTapLikeModifier: ViewModifier {
    let hasLiked: Bool
    @Binding var likeAnimation: Bool
    let handleLikeTapped: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                if !hasLiked {
                    handleLikeTapped()
                }
                likeAnimation = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000)) {
                    likeAnimation = false
                }
            }
    }
}

extension View {
    func doubleTapToLike(
        hasLiked: Bool,
        likeAnimation: Binding<Bool>,
        handleLikeTapped: @escaping () -> Void
    ) -> some View {
        self.modifier(DoubleTapLikeModifier(hasLiked: hasLiked, likeAnimation: likeAnimation, handleLikeTapped: handleLikeTapped))
    }
}

struct LikeAnimationModifier: ViewModifier {
    @Binding var isAnimating: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1 : 0)
            .opacity(isAnimating ? 1 : 0)
            // ProMotion-optimized spring animation for 120Hz displays
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isAnimating)
    }
}

extension View {
    func likeAnimation(_ isAnimating: Binding<Bool>) -> some View {
        self.modifier(LikeAnimationModifier(isAnimating: isAnimating))
    }
}
