//
//  PhotoGridIOS18Functions.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import UIKit

/// iOS 18-specific functions for PhotoGrid auto-scrolling behavior
@available(iOS 18.0, *)
extension PhotoGridIOS18 {
    /// Handles changes in scroll direction during drag selection.
    /// Manages the timer that performs continuous scrolling.
    /// - Parameter newDirection: The new scroll direction (.up, .down, or .none)
    internal func handleScrollDirectionChange(_ newDirection: ScrollDirection) {
        if newDirection != .none {
            guard scrollTimer == nil else { return }
            
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                if newDirection == .up {
                    targetScrollOffset += 3
                    localScrollPosition.scrollTo(y: targetScrollOffset)
                } else if newDirection == .down {
                    targetScrollOffset -= 3
                    localScrollPosition.scrollTo(y: targetScrollOffset)
                }
            }
            
            scrollTimer?.fire()
        } else {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
    }
    
    /// Checks if touch location is near screen edges and starts/stops scrolling.
    /// - Parameter location: The current touch location in global coordinates
    internal func checkAndHandleScrolling(at location: CGPoint) {
        let screenHeight = UIScreen.main.bounds.height
        let distanceFromBottom = screenHeight - location.y
        let distanceFromTop = location.y
        let scrollThreshold: CGFloat = 150
        
        if distanceFromBottom < scrollThreshold || distanceFromTop < scrollThreshold {
            let direction: ScrollDirection = distanceFromTop < scrollThreshold ? .down : .up
            currentScrollDirection = direction
            
            if scrollTimer == nil {
                startScrolling()
            }
        } else {
            currentScrollDirection = .none
            stopScrolling()
        }
    }
    
    /// Starts continuous auto-scrolling with variable speed based on distance from edge.
    /// Closer to the edge = faster scrolling.
    internal func startScrolling() {
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            guard
                  let touchLoc = self.currentTouchLocation,
                  self.currentScrollDirection != .none else { return }

            let screenHeight = UIScreen.main.bounds.height
            let scrollThreshold: CGFloat = 150

            let distanceFromEdge: CGFloat
            if self.currentScrollDirection == .down {
                distanceFromEdge = touchLoc.y
            } else {
                distanceFromEdge = screenHeight - touchLoc.y
            }

            let normalizedDistance = max(0, min(1, (scrollThreshold - distanceFromEdge) / scrollThreshold))
            let baseSpeed: CGFloat = 1.5
            let maxSpeedMultiplier: CGFloat = 4.0

            let speedMultiplier = 1 + (normalizedDistance * maxSpeedMultiplier * (0.7 + 0.3 * normalizedDistance))
            let speed = baseSpeed * speedMultiplier

            if self.currentScrollDirection == .up {
                self.targetScrollOffset += speed
            } else {
                self.targetScrollOffset -= speed
            }

            self.localScrollPosition.scrollTo(y: self.targetScrollOffset)

            // iOS 26: Update selection as cells scroll under stationary finger
            if #available(iOS 26, *) {
                if self.dragSelectionHandler.isDragSelectionActive {
                    self.handleIOS26DragSelection(at: touchLoc)
                }
            }
        }
        scrollTimer?.fire()
    }
    
    /// Stops auto-scrolling and cleans up the timer.
    internal func stopScrolling() {
        if scrollTimer != nil {
            scrollTimer?.invalidate()
            scrollTimer = nil
            currentScrollDirection = .none
        }
    }
}
