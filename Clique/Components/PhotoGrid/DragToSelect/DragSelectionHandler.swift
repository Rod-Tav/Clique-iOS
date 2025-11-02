//
//  DragSelectionHandler.swift
//  Clique
//
//  Centralized drag selection handling logic for photo grids
//

import Observation
import Photos
import UIKit

/// Manages drag-to-select functionality for photo grids.
/// 
/// This handler provides a centralized way to handle drag gestures for selecting
/// multiple photos in a grid view. It supports both additive selection (adding
/// new items to selection) and subtractive selection (removing items from selection).
///
/// Features:
/// - Drag to select multiple photos
/// - Auto-scrolling when dragging near edges
/// - Support for both adding and removing selections
/// - Integration with CreateViewModel for selection state management
@Observable final class DragSelectionHandler {
    /// Properties tracking the current drag selection state
    var dragSelectionProperties = DragSelectionProperties()

    /// Properties for auto-scrolling behavior when dragging near edges
    var scrollProperties = DragScrollProperties()

    /// Maps each asset to its frame location in the view for hit testing
    var assetLocations: [PHAsset: CGRect] = [:]

    /// Reference to the pan gesture recognizer being handled
    var panGesture: UIPanGestureRecognizer?

    /// Whether drag selection is currently active
    var isDragSelectionActive: Bool = false

    /// Array of all assets that can be selected
    private var assets: [PHAsset] = []

    /// Weak reference to the view model managing selection state
    private weak var viewModel: CreateViewModel?
        
    /// Configures the handler with assets and view model.
    /// - Parameters:
    ///   - assets: Array of PHAsset objects that can be selected
    ///   - viewModel: The CreateViewModel that manages selection state
    func configure(assets: [PHAsset], viewModel: CreateViewModel) {
        self.assets = assets
        self.viewModel = viewModel
    }
    
    /// Handles pan gesture for drag selection.
    /// - Parameters:
    ///   - gesture: The pan gesture recognizer
    ///   - isDragSelectionEnabled: Whether drag selection is enabled (default: true)
    func handlePanGesture(_ gesture: UIPanGestureRecognizer, isDragSelectionEnabled: Bool = true) {
        if panGesture == nil {
            panGesture = gesture
            gesture.isEnabled = isDragSelectionEnabled
        }
        
        let state = gesture.state
        
        if state == .began || state == .changed {
            onDragGestureChange(gesture)
        } else if state == .ended {
            onDragGestureEnded(gesture)
        } else if state == .cancelled || state == .failed {
            onDragGestureCancelled(gesture)
        }
    }
    
    /// Processes ongoing drag gesture changes to update selection.
    private func onDragGestureChange(_ gesture: UIPanGestureRecognizer) {
        let position = gesture.location(in: gesture.view)

        // Check if we need to auto-scroll
        scrollProperties.direction = scrollProperties.topRegion.contains(position) ? .down :
                                   scrollProperties.bottomRegion.contains(position) ? .up : .none

        // Find which asset the gesture is over
        if let (index, asset) = findAssetAtPosition(position) {
            if dragSelectionProperties.startIndex == nil {
                // Starting a new drag selection
                isDragSelectionActive = true
                dragSelectionProperties.startIndex = index
                dragSelectionProperties.previousSelectedAssets = viewModel?.selectedAssets ?? []
                dragSelectionProperties.isDeletingSelection = viewModel?.selectedAssets.contains(asset) ?? false
            }
            
            dragSelectionProperties.endIndex = index
            
            // Update selection based on drag range
            if let start = dragSelectionProperties.startIndex,
               let end = dragSelectionProperties.endIndex {
                let range = start <= end ? start...end : end...start
                let assetsInRange = range.compactMap { index in
                    index < assets.count ? assets[index] : nil
                }
                
                if dragSelectionProperties.isDeletingSelection {
                    // Remove selection from dragged assets
                    let assetsToRemove = Set(assetsInRange).intersection(dragSelectionProperties.previousSelectedAssets)
                    dragSelectionProperties.toBeRemovedAssets = assetsToRemove
                    
                    // Update viewModel selection
                    viewModel?.selectedAssets = dragSelectionProperties.previousSelectedAssets.subtracting(assetsToRemove)
                } else {
                    // Add selection to dragged assets
                    viewModel?.selectedAssets = dragSelectionProperties.previousSelectedAssets.union(Set(assetsInRange))
                    dragSelectionProperties.toBeRemovedAssets = []
                }
            }
        }
    }
    
    /// Finalizes selection when drag gesture ends.
    private func onDragGestureEnded(_ gesture: UIPanGestureRecognizer) {
        // Finalize the selection
        if !dragSelectionProperties.toBeRemovedAssets.isEmpty {
            viewModel?.selectedAssets = (viewModel?.selectedAssets ?? []).subtracting(dragSelectionProperties.toBeRemovedAssets)
        }

        // Reset drag selection properties
        isDragSelectionActive = false
        dragSelectionProperties.previousSelectedAssets = viewModel?.selectedAssets ?? []
        dragSelectionProperties.startIndex = nil
        dragSelectionProperties.endIndex = nil
        dragSelectionProperties.isDeletingSelection = false
        dragSelectionProperties.toBeRemovedAssets = []

        resetScrollTimer()
    }
    
    /// Handles cancelled drag gesture by resetting state.
    private func onDragGestureCancelled(_ gesture: UIPanGestureRecognizer) {
        // Gesture was cancelled
        if !dragSelectionProperties.toBeRemovedAssets.isEmpty {
            viewModel?.selectedAssets = (viewModel?.selectedAssets ?? []).subtracting(dragSelectionProperties.toBeRemovedAssets)
        }

        // Reset drag selection properties
        isDragSelectionActive = false
        dragSelectionProperties.previousSelectedAssets = viewModel?.selectedAssets ?? []
        dragSelectionProperties.startIndex = nil
        dragSelectionProperties.endIndex = nil
        dragSelectionProperties.isDeletingSelection = false
        dragSelectionProperties.toBeRemovedAssets = []

        // Reset scroll direction
        scrollProperties.direction = .none
    }
    
    /// Finds the asset at a given position using hit testing.
    /// - Parameter position: The position to check
    /// - Returns: Tuple with index and asset if found, nil otherwise
    private func findAssetAtPosition(_ position: CGPoint) -> (index: Int, asset: PHAsset)? {
        for (index, asset) in assets.enumerated() {
            if let rect = assetLocations[asset], rect.contains(position) {
                return (index, asset)
            }
        }
        return nil
    }
    
    /// Resets the auto-scroll timer and related properties.
    func resetScrollTimer() {
        scrollProperties.manualScrollOffset = 0
        scrollProperties.timer?.invalidate()
        scrollProperties.timer = nil
        scrollProperties.direction = .none
    }
    
    /// Handles changes in scroll direction for auto-scrolling.
    /// - Parameter newDirection: The new scroll direction
    func handleScrollDirectionChange(_ newDirection: ScrollDirection) {
        if newDirection != .none {
            guard scrollProperties.timer == nil else { return }
            scrollProperties.manualScrollOffset = scrollProperties.currentScrollOffset
            
            scrollProperties.timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if newDirection == .up {
                    self.scrollProperties.manualScrollOffset += 3
                } else if newDirection == .down {
                    self.scrollProperties.manualScrollOffset -= 3
                }
            }
            
            scrollProperties.timer?.fire()
        } else {
            resetScrollTimer()
        }
    }
}
