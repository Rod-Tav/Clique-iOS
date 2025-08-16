//
//  PhotoGridView.swift
//  Clique
//
//  Reusable photo grid component with drag selection support
//

import SwiftUI
import Photos

/// Displays a grid of photos with optional drag-to-select functionality.
/// Automatically uses iOS 18 features when available.
struct PhotoGridView: View {
    @Environment(CreateViewModel.self) var viewModel
    
    /// Array of photo assets to display
    let assets: [PHAsset]
    /// Cache of thumbnail images
    let thumbnailCache: [PHAsset: UIImage]
    /// Optional custom column layout (defaults to 3 columns)
    var columns: [GridItem]?
    /// Whether drag selection is enabled
    let isDragSelectionEnabled: Bool = true
    /// Callback when a photo is tapped
    let onToggleSelection: (PHAsset) -> Void
    /// Callback to load a thumbnail
    let onLoadThumbnail: (PHAsset) -> Void
    
    @State private var dragSelectionHandler = DragSelectionHandler()
    @State private var scrollPositionIOS18 = ScrollPositionIOS18()
    
    /// Default 3-column grid layout
    private var defaultColumns: [GridItem] {
        let spacing: CGFloat = 2
        let totalSpacing = spacing * 2
        let itemWidth = (UIScreen.width - totalSpacing) / 3
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: 3)
    }
    
    var body: some View {
        // Configure the drag selection handler with current assets and viewModel
        let _ = dragSelectionHandler.configure(assets: assets, viewModel: viewModel)
        
        Group {
            if #available(iOS 18.0, *) {
                PhotoGridIOS18(
                    assets: assets,
                    viewModel: viewModel,
                    thumbnailCache: thumbnailCache,
                    columns: columns ?? defaultColumns,
                    isDragSelectionEnabled: isDragSelectionEnabled,
                    dragSelectionHandler: dragSelectionHandler,
                    scrollPositionIOS18: scrollPositionIOS18,
                    onToggleSelection: onToggleSelection,
                    onLoadThumbnail: onLoadThumbnail
                )
            } else {
                PhotoGridIOS17(
                    assets: assets,
                    viewModel: viewModel,
                    thumbnailCache: thumbnailCache,
                    columns: columns ?? defaultColumns,
                    onToggleSelection: onToggleSelection,
                    onLoadThumbnail: onLoadThumbnail
                )
            }
        }
    }
}

/// iOS 17 compatible photo grid without drag selection
struct PhotoGridIOS17: View {
    let assets: [PHAsset]
    let viewModel: CreateViewModel
    let thumbnailCache: [PHAsset: UIImage]
    let columns: [GridItem]
    let onToggleSelection: (PHAsset) -> Void
    let onLoadThumbnail: (PHAsset) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(assets.enumerated()), id: \.element) { index, asset in
                    PhotoGridCell(
                        asset: asset,
                        isSelected: viewModel.selectedAssets.contains(asset),
                        thumbnail: thumbnailCache[asset],
                        isBeingRemoved: false
                    ) {
                        onToggleSelection(asset)
                    }
                    .task {
                        onLoadThumbnail(asset)
                    }
                }
            }
        }
    }
}
