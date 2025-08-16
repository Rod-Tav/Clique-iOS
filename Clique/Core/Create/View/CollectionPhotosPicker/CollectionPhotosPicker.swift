//
//  CollectionPhotosPicker.swift
//  Clique
//
//  Created by Rod Tavangar on 2/28/25.
//

import SwiftUI
import Photos
import PhotosUI

struct CollectionPhotosPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) var presentToast
    
    @Environment(TabViewCoordinator.self) var tabViewCoordinator
    
    @Environment(CreateViewModel.self) var viewModel
    @Environment(PhotoPickerContext.self) var context
    
    @Binding var shouldProcess: Bool
    @Binding var isProcessing: Bool
    
    @State internal var flicksAssets: [PHAsset] = [] // All photos for Flicks tab
    @State internal var sharedAlbums: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []
    @State internal var otherAlbums: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []
    @State internal  var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    @State private var selectedTab: PickerTab = .flicks
    @State private var selectedTabIndex: Int? = 0
    @State private var tabProgress: CGFloat = .zero
    @State private var albums: [(collection: PHAssetCollection, title: String, count: Int)] = []
    @State private var hasLoadedAlbums: Bool = false
    
    private enum PickerTab {
        case flicks
        case collections
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if authorizationStatus == .authorized {
                picker
            } else if authorizationStatus == .denied {
                VStack(spacing: 20) {
                    Text("Photo Access Required")
                        .font(.title2)
                    Text("Please allow access to your photos in Settings")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView()
                    .infiniteFrame()
            }
        }
        .task {
            guard !hasLoadedAlbums else { return }
            checkPhotoLibraryAuthorization()
            hasLoadedAlbums = true
        }
        .onChange(of: shouldProcess) { _, newValue in
            if newValue {
                processSelectedPhotos()
                shouldProcess = false
            }
        }
        .onChange(of: context.isProcessing) { _, newValue in
            isProcessing = newValue
        }
        .primaryBackground()
    }
    
    // MARK:  Tab Picker Bar
    private var picker: some View {
        VStack(spacing: 0) {
            tabPickerBar
            tabs
        }
    }
    
    /// Tab selector with indicator bar
    private var tabPickerBar: some View {
        TabsWithIndicatorBar(
            tabCount: 2,
            alignment: .bottom,
            tabProgress: $tabProgress
        ) {
            Group {
                TextTab(
                    "PHOTOS",
                    isSelected: selectedTabIndex == 0
                ) {
                    selectedTabIndex = 0
                    selectedTab = .flicks
                }
                
                TextTab(
                    "ALBUMS",
                    isSelected: selectedTabIndex == 1
                ) {
                    selectedTabIndex = 1
                    selectedTab = .collections
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var tabs: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                flicks
                collections
            }
            .scrollTargetLayout()
            .offsetX { value in
                tabProgress = -value / (UIScreen.width * 2)
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selectedTabIndex)
        .scrollClipDisabled()
    }
    
    private var flicks: some View {
        PhotoGridView(
            assets: flicksAssets,
            thumbnailCache: context.thumbnailCache,
            columns: context.columns,
            onToggleSelection: toggleSelection,
            onLoadThumbnail: { context.loadThumbnail(for: $0) }
        )
        .containerRelativeFrame(.horizontal)
        .id(0)
    }
    
    private var collections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Shared Albums
                if !sharedAlbums.isEmpty {
                    sharedAlbumsCarousel
                }
                
                // Other Albums
                if !otherAlbums.isEmpty {
                    otherAlbumsCarousel
                }
            }
            .padding(.vertical)
        }
        .containerRelativeFrame(.horizontal)
        .id(1)
    }
    
    private var sharedAlbumsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Albums")
                .font(.headline)
                .foregroundStyle(Color.theme.textPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sharedAlbums, id: \.collection) { album in
                        NavigationLink(value: CreateFlowDestination.album(assetCollection: album.collection, title: album.title)) {
                            AlbumThumbnail(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var otherAlbumsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Albums")
                .font(.headline)
                .foregroundStyle(Color.theme.textPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(otherAlbums, id: \.collection) { album in
                        NavigationLink(value: CreateFlowDestination.album(assetCollection: album.collection, title: album.title)) {
                            AlbumThumbnail(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
