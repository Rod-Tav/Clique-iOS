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
                Text(title)
                    .font(.callout.weight(.semibold))
                    .textPrimary()
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
            Spacer()
                .frame(24)
        } else {
            Button {
                processSelectedPhotos()
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.selectedAssets.count)") // Photo count
                        
                        IconImage("images-posts", color: .theme.iconPrimary, size: 20)
                    }
                    
                    Text("Add")
                }
                .font(.caption.bold())
                .textPrimary()
            }
            .font(.callout)
            .disabled(context.isProcessing)
        }
    }
}

