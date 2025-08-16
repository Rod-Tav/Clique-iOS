//
//  DragSelectionTypes.swift
//  Clique
//
//  Shared types for drag-to-select functionality across photo pickers
//

import SwiftUI
import Photos

/// Properties tracking the current drag selection state.
struct DragSelectionProperties {
    /// Index where drag selection started
    var startIndex: Int?
    /// Current index being dragged over
    var endIndex: Int?
    /// Assets selected before drag began
    var previousSelectedAssets: Set<PHAsset> = []
    /// Assets to be removed during drag
    var toBeRemovedAssets: Set<PHAsset> = []
    /// Whether drag is removing from selection
    var isDeletingSelection: Bool = false
}

/// Properties for auto-scrolling during drag operations.
struct DragScrollProperties {
    /// Current scroll position
    var currentScrollOffset: CGFloat = 0
    /// Manual scroll offset for auto-scroll
    var manualScrollOffset: CGFloat = 0
    /// Timer for auto-scroll updates
    var timer: Timer?
    /// Current scroll direction
    var direction: ScrollDirection = .none
    /// Region that triggers downward scroll
    var topRegion: CGRect = .zero
    /// Region that triggers upward scroll
    var bottomRegion: CGRect = .zero
    
    mutating func setRegion(_ region: ScrollRegion, to rect: CGRect) {
        if region == .top {
            self.topRegion = rect
        } else {
            self.bottomRegion = rect
        }
    }
}

/// Direction for auto-scrolling.
enum ScrollDirection {
    case up
    case down
    case none
}

/// Region for detecting auto-scrolling.
enum ScrollRegion {
    case top, bottom
}

/// iOS 18+ scroll position wrapper for compatibility.
struct ScrollPositionIOS18 {
    var position: Any? // Will be ScrollPosition on iOS 18+
    var currentScrollOffset: CGFloat = 0
    var manualScrollOffset: CGFloat = 0
    var timer: Timer?
    
    init() {
        if #available(iOS 18.0, *) {
            self.position = ScrollPosition()
        } else {
            self.position = nil
        }
    }
}
