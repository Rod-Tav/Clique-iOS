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
    
    var body: some View {
        ScrollView {
            photosGrid
        }
        .overlay(alignment: .top) { scrollDetectionRegion(.top) }
        .overlay(alignment: .bottom) { scrollDetectionRegion(.bottom) }
        .scrollPosition($localScrollPosition)
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let location = value.location
                    touchLocation = location
                    currentTouchLocation = location
                    checkAndHandleScrolling(at: location)
                }
                .onEnded { _ in
                    touchLocation = nil
                    currentTouchLocation = nil
                    stopScrolling()
                }
        )
        .gesture(
            PanGesture { gesture in
                dragSelectionHandler.handlePanGesture(gesture, isDragSelectionEnabled: isDragSelectionEnabled)
            }
        )
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
