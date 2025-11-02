//
//  PhotoGridIOS18.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI
import Photos

/// iOS 18+ photo grid with drag-to-select and auto-scroll capabilities.
@available(iOS 18.0, *)
struct PhotoGridIOS18: View {
    /// Assets to display in the grid
    let assets: [PHAsset]
    /// View model managing selection state
    let viewModel: CreateViewModel
    /// Cache of loaded thumbnails
    let thumbnailCache: [PHAsset: UIImage]
    /// Grid column configuration
    let columns: [GridItem]
    /// Whether drag selection is enabled
    let isDragSelectionEnabled: Bool
    /// Handler for drag selection logic
    @Bindable var dragSelectionHandler: DragSelectionHandler
    /// iOS 18 scroll position wrapper
    @State var scrollPositionIOS18: ScrollPositionIOS18
    /// Callback for photo tap
    let onToggleSelection: (PHAsset) -> Void
    /// Callback to load thumbnail
    let onLoadThumbnail: (PHAsset) -> Void
    
    // Auto-scroll state
    @State internal var localScrollPosition = ScrollPosition()
    @State internal var scrollTimer: Timer?
    @State internal var targetScrollOffset: CGFloat = 0
    @State private var touchLocation: CGPoint?
    @State internal var currentTouchLocation: CGPoint?
    @State internal var currentScrollDirection: ScrollDirection = .none

    // iOS 26: Track initial drag position to distinguish tap vs drag
    @State private var initialDragLocation: CGPoint?
    
    var body: some View {
        ScrollView {
            photosGrid
        }
        .overlay(alignment: .top) { scrollDetectionRegion(.top) }
        .overlay(alignment: .bottom) { scrollDetectionRegion(.bottom) }
        .scrollPosition($localScrollPosition)
        // iOS 26: Disable scrolling only when actively dragging over cells
        .scrollDisabled(dragSelectionHandler.isDragSelectionActive)
        .onScrollGeometryChange(for: CGFloat.self, of: {
            $0.contentOffset.y + $0.contentInsets.top
        }, action: { oldValue, newValue in
            scrollPositionIOS18.currentScrollOffset = newValue
            targetScrollOffset = newValue
            dragSelectionHandler.scrollProperties.currentScrollOffset = newValue
        })
        .onChange(of: dragSelectionHandler.scrollProperties.direction) { oldValue, newValue in
            handleScrollDirectionChange(newValue)
        }
        .onAppear {
            scrollPositionIOS18.position = localScrollPosition
        }
        .background(
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
        )
        // Gesture handling for both iOS 18 and iOS 26
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let location = value.location
                    touchLocation = location
                    currentTouchLocation = location

                    // iOS 26: Handle drag selection with horizontal bias
                    if #available(iOS 26, *) {
                        if initialDragLocation == nil {
                            initialDragLocation = location
                        }

                        // Calculate horizontal and vertical movement
                        if let initial = initialDragLocation {
                            let dx = abs(location.x - initial.x)
                            let dy = abs(location.y - initial.y)

                            // Only activate drag selection if:
                            // 1. Movement is more horizontal than vertical
                            // 2. Horizontal movement exceeds minimum threshold (10pt)
                            if dx > dy && dx > 10 {
                                handleIOS26DragSelection(at: location)
                            }
                        }
                    }

                    checkAndHandleScrolling(at: location)
                }
                .onEnded { _ in
                    touchLocation = nil
                    currentTouchLocation = nil
                    initialDragLocation = nil

                    // iOS 26: Finalize selection
                    if #available(iOS 26, *) {
                        finalizeIOS26Selection()
                    }

                    stopScrolling()
                }
        )
        // iOS 18: Use PanGesture for UIKit-based selection
        .if(!.iOS26) { view in
            view.gesture(
                PanGesture { gesture in
                    dragSelectionHandler.handlePanGesture(gesture, isDragSelectionEnabled: isDragSelectionEnabled)
                }
            )
        }
    }
    
    /// Grid of photo cells with selection tracking
    private var photosGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(assets.enumerated()), id: \.element) { index, asset in
                PhotoGridCell(
                    asset: asset,
                    isSelected: viewModel.selectedAssets.contains(asset),
                    thumbnail: thumbnailCache[asset],
                    isBeingRemoved: dragSelectionHandler.dragSelectionProperties.toBeRemovedAssets.contains(asset)
                ) {
                    onToggleSelection(asset)
                }
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .global)
                } action: { newValue in
                    dragSelectionHandler.assetLocations[asset] = newValue
                }
                .task {
                    onLoadThumbnail(asset)
                }
            }
        }
    }

    /// Finds asset at a given location
    private func findAssetAtLocation(_ location: CGPoint) -> (index: Int, asset: PHAsset)? {
        for (index, asset) in assets.enumerated() {
            if let rect = dragSelectionHandler.assetLocations[asset], rect.contains(location) {
                return (index, asset)
            }
        }
        return nil
    }

    /// iOS 26: Handles drag selection with proper ScrollView coordination
    internal func handleIOS26DragSelection(at location: CGPoint) {
        // First check: did we START on a cell?
        if dragSelectionHandler.dragSelectionProperties.startIndex == nil {
            guard let initial = initialDragLocation,
                  let (index, asset) = findAssetAtLocation(initial) else {
                // Didn't start on a cell - don't activate drag selection
                return
            }

            // Started on a cell - activate drag selection
            dragSelectionHandler.isDragSelectionActive = true
            dragSelectionHandler.dragSelectionProperties.startIndex = index
            dragSelectionHandler.dragSelectionProperties.previousSelectedAssets = viewModel.selectedAssets
            dragSelectionHandler.dragSelectionProperties.isDeletingSelection = viewModel.selectedAssets.contains(asset)
        }

        // Find current cell (if any)
        guard let (index, _) = findAssetAtLocation(location) else {
            // Not over a cell currently - keep current selection state
            return
        }

        // Update current drag position
        dragSelectionHandler.dragSelectionProperties.endIndex = index

        // Update selection in real-time
        if let start = dragSelectionHandler.dragSelectionProperties.startIndex,
           let end = dragSelectionHandler.dragSelectionProperties.endIndex {
            let range = start <= end ? start...end : end...start
            let assetsInRange = range.compactMap { index in
                index < assets.count ? assets[index] : nil
            }

            if dragSelectionHandler.dragSelectionProperties.isDeletingSelection {
                // Deselection mode
                let assetsToRemove = Set(assetsInRange).intersection(dragSelectionHandler.dragSelectionProperties.previousSelectedAssets)
                dragSelectionHandler.dragSelectionProperties.toBeRemovedAssets = assetsToRemove
                viewModel.selectedAssets = dragSelectionHandler.dragSelectionProperties.previousSelectedAssets.subtracting(assetsToRemove)
            } else {
                // Selection mode
                viewModel.selectedAssets = dragSelectionHandler.dragSelectionProperties.previousSelectedAssets.union(Set(assetsInRange))
                dragSelectionHandler.dragSelectionProperties.toBeRemovedAssets = []
            }
        }
    }

    /// iOS 26: Finalizes selection when drag ends
    private func finalizeIOS26Selection() {
        if dragSelectionHandler.isDragSelectionActive {
            // Finalize any pending removals
            if !dragSelectionHandler.dragSelectionProperties.toBeRemovedAssets.isEmpty {
                viewModel.selectedAssets = viewModel.selectedAssets.subtracting(dragSelectionHandler.dragSelectionProperties.toBeRemovedAssets)
            }
        }

        // Reset all state
        dragSelectionHandler.isDragSelectionActive = false
        dragSelectionHandler.dragSelectionProperties.startIndex = nil
        dragSelectionHandler.dragSelectionProperties.endIndex = nil
        dragSelectionHandler.dragSelectionProperties.previousSelectedAssets = []
        dragSelectionHandler.dragSelectionProperties.isDeletingSelection = false
        dragSelectionHandler.dragSelectionProperties.toBeRemovedAssets = []
    }
    
    /// Invisible regions at top/bottom that trigger auto-scrolling
    private func scrollDetectionRegion(_ region: ScrollRegion) -> some View {
        Rectangle()
            .foregroundStyle(.clear)
            .height(60)
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                dragSelectionHandler.scrollProperties.setRegion(region, to: newValue)
            }
    }
}
