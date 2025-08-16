//
//  HeroCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 1/19/25.
//

import SwiftUI

@Observable
class HeroCoordinator {
    var animateView: Bool = false
    var showDetailView: Bool = false
    var offset: CGSize = .zero
    var imageUrls: PhotoUrls? = nil
    var dragProgress: CGFloat = 0
    
    var animationIsOpen: Bool = true // vs close animation (direction)
    
    func toggleView(show: Bool, completion: (() -> Void)? = nil) {
        if show {
//            withAnimation(.interactiveSpring(duration: 0.3)) {
            withAnimation(.snappy(duration: 0.3, extraBounce: 0), completionCriteria: .logicallyComplete) {
                animateView = true
            } completion: {
                self.animationIsOpen = false
                self.showDetailView = true
            }
        } else {
            showDetailView = false
//            withAnimation(.snappy(duration: 0.3, extraBounce: 0), completionCriteria: .logicallyComplete) {
            withAnimation(.interpolatingSpring(stiffness: 270, damping: 28.5, initialVelocity: 12), completionCriteria: .removed) {
                animateView = false
                offset = .zero
            }
            completion: {
                completion?()
            }
        }
    }
    
    func resetAnimationProperties() {
        animateView = false
        showDetailView = false
        animationIsOpen = true
        offset = .zero
        imageUrls = nil
        dragProgress = 0
    }
}
