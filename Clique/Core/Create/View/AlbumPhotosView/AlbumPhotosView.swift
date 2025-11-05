//
//  AlbumPhotosView.swift
//  Clique
//
//  Created by Assistant on 8/2/25.
//

import SwiftUI
import Photos
import Toasts

struct AlbumPhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) var presentToast
    
    @Environment(TabViewCoordinator.self) var tabViewCoordinator
    
    @Environment(CreateViewModel.self) var viewModel
    @Environment(PhotoPickerContext.self) var context
    
    @State var albumAssets: [PHAsset] = []
    @State var showClearConfirmation: Bool = false

    let assetCollection: PHAssetCollection
    let title: String
    
    // Computed property for checking if all photos are selected
    var allSelected: Bool {
        !albumAssets.isEmpty && albumAssets.allSatisfy { viewModel.selectedAssets.contains($0) }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                
                PhotoGridView(
                    assets: albumAssets,
                    thumbnailCache: context.thumbnailCache,
                    columns: context.columns,
                    onToggleSelection: toggleSelection,
                    onLoadThumbnail: { context.loadThumbnail(for: $0) }
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .primaryBackground()
            .task {
                loadPhotosFromAlbum()
            }
            .confirmationDialog(
                "Clear \(viewModel.selectedAssets.count) selected photos?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllSelections()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all selected photos and any processed data.")
            }
        }
    }
    
    // MARK: Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                ZStack(alignment: .leading) {
                    if viewModel.selectedAssets.count > 0 {
                        trailingIcon
                            .hidden()
                    }
                    
                    BackButton(size: 24)
                }
            },
            header: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .textPrimary()
                    
                    if !albumAssets.isEmpty {
                        SmallCTA(
                            type: .primary,
                            text: allSelected ? "Deselect All" : "Select All",
                            action: {
                                if allSelected {
                                    deselectAllPhotos()
                                } else {
                                    selectAllPhotos()
                                }
                            }
                        )
                    }
                }
            },
            trailingIcon: { trailingIcon }
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .primaryBackground()
    }
    
    @ViewBuilder private var trailingIcon: some View {
        if viewModel.selectedAssets.isEmpty {
            // No selection - show nothing or spacer
            Spacer()
                .frame(24)
        } else {
            ClearPhotosButton(count: viewModel.selectedAssets.count, action: handleClearTap)
        }
    }
}

