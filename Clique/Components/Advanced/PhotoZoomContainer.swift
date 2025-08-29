//
//  PhotoZoomContainer.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import SwiftUI

struct PhotoZoomContainer<Content: View>: View {
    let maxScale: CGFloat
    @Binding var scale: CGFloat
    @Binding var dragOffset: CGSize
    let content: Content
    
    @GestureState private var isDragging = false
    @State private var initialDragOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var zoomAnchor: UnitPoint = .center
    @State private var isZooming: Bool = false
    
    init(
        maxScale: CGFloat = 5.0,
        scale: Binding<CGFloat>,
        dragOffset: Binding<CGSize>,
        @ViewBuilder content: () -> Content
    ) {
        self.maxScale = maxScale
        self._scale = scale
        self._dragOffset = dragOffset
        self.content = content()
    }
    
    // Calculate maximum allowed horizontal offset based on zoom
    // The image should not be dragged so far that its edge comes inside the screen bounds
    private var maxHorizontalOffset: CGFloat {
        // When zoomed, the image extends beyond the container
        // We can drag until the edge of the image reaches the edge of the container
        let scaledWidth = containerSize.width * scale
        let availableWidth = max(0, scaledWidth - containerSize.width)
        return availableWidth / 2
    }
    
    // Calculate maximum allowed vertical offset based on zoom
    private var maxVerticalOffset: CGFloat {
        // When zoomed, the image extends beyond the container
        // We can drag until the edge of the image reaches the edge of the container
        let scaledHeight = containerSize.height * scale
        let availableHeight = max(0, scaledHeight - containerSize.height)
        return availableHeight / 2
    }
    
    // Constrain offset to boundaries - prevent dragging image edges inside screen
    private func constrainedOffset(_ proposedOffset: CGSize) -> CGSize {
        guard scale > 1.0 else {
            return proposedOffset
        }
        
        let maxH = maxHorizontalOffset
        let maxV = maxVerticalOffset
        var width = proposedOffset.width
        var height = proposedOffset.height
        
        // Clamp horizontal boundaries (image edge should not come inside screen)
        if width > maxH {
            width = maxH
        } else if width < -maxH {
            width = -maxH
        }
        
        // Clamp vertical boundaries (image edge should not come inside screen)
        if height > maxV {
            height = maxV
        } else if height < -maxV {
            height = -maxV
        }
        
        return CGSize(width: width, height: height)
    }
    
    // Check if offset needs snap-back (if image edge is inside screen bounds)
    private func snapBackIfNeeded() {
        guard scale > 1.0 else { return }
        
        let maxH = maxHorizontalOffset
        let maxV = maxVerticalOffset
        var needsAnimation = false
        var targetWidth = dragOffset.width
        var targetHeight = dragOffset.height
        
        // Check horizontal boundaries
        if dragOffset.width > maxH {
            targetWidth = maxH
            needsAnimation = true
        } else if dragOffset.width < -maxH {
            targetWidth = -maxH
            needsAnimation = true
        }
        
        // Check vertical boundaries
        if dragOffset.height > maxV {
            targetHeight = maxV
            needsAnimation = true
        } else if dragOffset.height < -maxV {
            targetHeight = -maxV
            needsAnimation = true
        }
        
        if needsAnimation {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = CGSize(width: targetWidth, height: targetHeight)
                initialDragOffset = CGSize(width: targetWidth, height: targetHeight)
            }
        } else {
            // Update initial offset for next drag
            initialDragOffset = dragOffset
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
                    .scaleEffect(scale, anchor: zoomAnchor)
                    .offset(dragOffset)
                    .onAppear {
                        containerSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        containerSize = newSize
                    }
                    .simultaneousGesture(
                        scale > 1.0 ? DragGesture()
                            .updating($isDragging) { _, state, _ in
                                state = true
                            }
                            .onChanged { value in
                                // When starting a new drag, capture the current offset
                                if !isDragging {
                                    initialDragOffset = dragOffset
                                }
                                let proposedOffset = CGSize(
                                    width: initialDragOffset.width + value.translation.width,
                                    height: initialDragOffset.height + value.translation.height
                                )
                                // Apply hard constraints during drag - don't allow dragging past boundaries
                                dragOffset = constrainedOffset(proposedOffset)
                            }
                            .onEnded { _ in
                                // Snap back to boundaries if needed
                                snapBackIfNeeded()
                            } : nil
                    )
                    .onChange(of: scale) { _, newScale in
                        // Reset drag offset when zooming back to 1x
                        if newScale <= 1.0 {
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = .zero
                                initialDragOffset = .zero
                                zoomAnchor = .center
                            }
                        } else {
                            // After zooming, check if we need to adjust position
                            snapBackIfNeeded()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // UIKit gesture overlay for proper zoom anchoring
                ZoomGestureHandler(
                    scale: $scale,
                    zoomAnchor: $zoomAnchor,
                    isZooming: $isZooming,
                    maxScale: maxScale,
                    minScale: 1.0
                )
            }
        }
    }
}