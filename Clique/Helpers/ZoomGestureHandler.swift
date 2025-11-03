//
//  ZoomGestureHandler.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import SwiftUI
import UIKit

/// Shared gesture handler for proper zoom anchoring and dragging using UIKit gestures
struct ZoomGestureHandler: UIViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var dragOffset: CGSize
    @Binding var zoomAnchor: UnitPoint
    @Binding var isZooming: Bool

    let maxScale: CGFloat
    let minScale: CGFloat
    let isInteractive: Bool
    let constrainOffset: (CGSize) -> CGSize
    let snapBackIfNeeded: () -> Void

    init(
        scale: Binding<CGFloat>,
        dragOffset: Binding<CGSize>,
        zoomAnchor: Binding<UnitPoint>,
        isZooming: Binding<Bool>,
        maxScale: CGFloat = 5.0,
        minScale: CGFloat = 1.0,
        isInteractive: Bool = true,
        constrainOffset: @escaping (CGSize) -> CGSize = { $0 },
        snapBackIfNeeded: @escaping () -> Void = {}
    ) {
        self._scale = scale
        self._dragOffset = dragOffset
        self._zoomAnchor = zoomAnchor
        self._isZooming = isZooming
        self.maxScale = maxScale
        self.minScale = minScale
        self.isInteractive = isInteractive
        self.constrainOffset = constrainOffset
        self.snapBackIfNeeded = snapBackIfNeeded
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = isInteractive

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinchGesture.delegate = context.coordinator

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = context.coordinator

        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(panGesture)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let parent: ZoomGestureHandler
        private var initialScale: CGFloat = 1.0
        private var initialDragOffset: CGSize = .zero
        
        init(_ parent: ZoomGestureHandler) {
            self.parent = parent
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                // Calculate anchor point from gesture location
                let location = gesture.location(in: gesture.view)
                if let bounds = gesture.view?.bounds {
                    let anchor = UnitPoint(
                        x: location.x / bounds.width,
                        y: location.y / bounds.height
                    )
                    parent.zoomAnchor = anchor
                }
                initialScale = parent.scale
                parent.isZooming = true
                
            case .changed:
                let newScale = initialScale * gesture.scale
                parent.scale = min(max(newScale, parent.minScale), parent.maxScale)
                
            case .ended, .cancelled, .failed:
                parent.isZooming = false
                parent.snapBackIfNeeded()
                
            default:
                break
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            // Only allow panning when zoomed in
            guard parent.scale > parent.minScale else { return }
            
            switch gesture.state {
            case .began:
                initialDragOffset = parent.dragOffset
                parent.isZooming = true // Set to true for interacting state
                
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                let proposedOffset = CGSize(
                    width: initialDragOffset.width + translation.x,
                    height: initialDragOffset.height + translation.y
                )
                parent.dragOffset = parent.constrainOffset(proposedOffset)
                
            case .ended, .cancelled, .failed:
                parent.isZooming = false // Set to false when done interacting
                parent.snapBackIfNeeded()
                
            default:
                break
            }
        }
        
        // Allow simultaneous pinch and pan gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}