//
//  ZoomGestureHandler.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import SwiftUI
import UIKit

/// Shared gesture handler for proper zoom anchoring using UIKit gestures
struct ZoomGestureHandler: UIViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var zoomAnchor: UnitPoint
    @Binding var isZooming: Bool
    
    let maxScale: CGFloat
    let minScale: CGFloat
    
    init(
        scale: Binding<CGFloat>,
        zoomAnchor: Binding<UnitPoint>,
        isZooming: Binding<Bool>,
        maxScale: CGFloat = 5.0,
        minScale: CGFloat = 1.0
    ) {
        self._scale = scale
        self._zoomAnchor = zoomAnchor
        self._isZooming = isZooming
        self.maxScale = maxScale
        self.minScale = minScale
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        
        view.addGestureRecognizer(pinchGesture)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: ZoomGestureHandler
        private var initialScale: CGFloat = 1.0
        
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
                
            default:
                break
            }
        }
    }
}