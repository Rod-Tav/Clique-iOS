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
        }
    }
    
    // MARK: Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                ZStack(alignment: .leading) {
                    if viewModel.selectedAssets.count > 0 {
                        TrailingIcon()
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
            trailingIcon: {
                TrailingIcon()
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .primaryBackground()
    }
    
    @ViewBuilder private func TrailingIcon() -> some View {
        if viewModel.selectedAssets.isEmpty {
            // No selection - show nothing or spacer
            Spacer()
                .frame(width: 24)
        } else {
            // Any selection - always show count and "Add" button
            Button {
                processSelectedPhotos()
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.selectedAssets.count)")
                        IconImage("images-posts", color: .theme.iconPrimary, size: 20)
                    }
                    Text("Add")
                }
                .font(.caption.bold())
                .textPrimary()
            }
            .disabled(context.isProcessing)
        }
    }
}

