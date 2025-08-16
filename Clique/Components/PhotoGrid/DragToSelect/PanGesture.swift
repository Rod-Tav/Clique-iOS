//
//  PanGesture.swift
//  Clique
//
//  Reusable UIKit pan gesture wrapper for SwiftUI
//

import SwiftUI
import UIKit

/// SwiftUI wrapper for UIKit's UIPanGestureRecognizer.
/// Enables pan gesture handling in SwiftUI views for drag selection.
public struct PanGesture: UIGestureRecognizerRepresentable {
    /// Closure called when gesture state changes
    var handle: (UIPanGestureRecognizer) -> ()
    
    /// Creates a pan gesture with a handler.
    /// - Parameter handle: Closure to handle gesture state changes
    public init(handle: @escaping (UIPanGestureRecognizer) -> ()) {
        self.handle = handle
    }
    
    public func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        return UIPanGestureRecognizer()
    }
    
    public func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        
    }
    
    public func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        handle(recognizer)
    }
}