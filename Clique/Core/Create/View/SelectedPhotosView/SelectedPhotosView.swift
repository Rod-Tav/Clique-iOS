//
//  SelectedPhotosView.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import SwiftUI
import Photos

struct SelectedPhotosView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentToast) var presentToast
    @Environment(CreateViewModel.self) var viewModel
    @Environment(PhotoPickerContext.self) var context

    @Environment(UserStore.self) var userStore
    @Environment(CollectionStore.self) var collectionStore
    @Environment(CollectionImageStore.self) var collectionImageStore
    @Environment(CliqueStore.self) var cliqueStore
    @Environment(TabViewCoordinator.self) var tabViewCoordinator

    @State var currentIndex: Int = 0
    @State var scrollPosition: PHAsset?
    @State var zoomScales: [PHAsset: CGFloat] = [:]
    @State var dragOffsets: [PHAsset: CGSize] = [:]
    @State var galleryProxy: ScrollViewProxy?

    // Sorting-related state
    @State var isSortingAssets: Bool = true

    // Upload-related state
    @State var activeSheet: SheetType?
    @State var isProcessing: Bool = false
    @State var processingProgress: Double = 0.0
    @State var processedCount: Int = 0
    @State var totalCount: Int = 0

    // Sheet type enum
    enum SheetType: Identifiable {
        case chooseCollection
        case newCollection

        var id: Int {
            switch self {
            case .chooseCollection: return 0
            case .newCollection: return 1
            }
        }
    }
    
    // Access ordered array for indexed access (sorted by creation date - library order)
    var selectedAssetsArray: [PHAsset] {
        viewModel.orderedSelectedAssets
    }

    // Check if current image is zoomed
    var isCurrentImageZoomed: Bool {
        guard currentIndex < selectedAssetsArray.count else { return false }
        let currentAsset = selectedAssetsArray[currentIndex]
        return (zoomScales[currentAsset] ?? 1.0) > 1.0
    }

    // Get current asset's media type
    var currentAssetMediaType: String? {
        guard currentIndex < selectedAssetsArray.count else { return nil }
        let asset = selectedAssetsArray[currentIndex]

        if asset.isLivePhoto {
            return "LIVE"
        } else if asset.isVideo {
            return "VIDEO"
        }
        return nil
    }
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ZStack {
            if isSortingAssets {
                // Loading state while sorting
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Processing...")
                        .font(.callout)
                        .textPrimary()
                }
                .primaryBackground()
            } else {
                // Normal view content
                VStack(spacing: 0) {
                    topBar
                    centerImagePreview
                    bottomCarousel
                    Spacer()
                    uploadButton
                }
                .primaryBackground()

                // Processing overlay
                if isProcessing {
                    ProcessingOverlay(
                        progress: processingProgress,
                        processedCount: processedCount,
                        totalCount: totalCount
                    )
                }
            }
        }
        .task {
            // Sort selected assets by creation date (library order) on background thread
            let selectedAssets = viewModel.selectedAssets

            let sortedAssets = await Task.detached(priority: .userInitiated) {
                selectedAssets.sorted {
                    ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
                }
            }.value

            // Update on main thread
            await MainActor.run {
                viewModel.orderedSelectedAssets = sortedAssets

                // Debug assertion: verify Set and Array are in sync
                assert(viewModel.selectedAssets.count == viewModel.orderedSelectedAssets.count,
                       "selectedAssets and orderedSelectedAssets out of sync! Set: \(viewModel.selectedAssets.count), Array: \(viewModel.orderedSelectedAssets.count)")

                // Initialize scroll position to first item
                if !selectedAssetsArray.isEmpty {
                    scrollPosition = selectedAssetsArray[0]
                }

                // Done sorting - show normal view
                isSortingAssets = false
            }
        }
        .onChange(of: viewModel.showNewCollectionSheet) { _, newValue in
            if newValue {
                activeSheet = .newCollection
                viewModel.showNewCollectionSheet = false // Reset to avoid conflicts
            }
        }
        .onChange(of: tabViewCoordinator.activeTab) { oldTab, newTab in
            // Auto-dismiss when tab switches away (mimics NavigationDestination auto-dismiss behavior)
            if oldTab != newTab {
                dismiss()
            }
        }
        .onChange(of: viewModel.shouldProcessAndUploadForNewCollection) { _, shouldUpload in
            if shouldUpload {
                viewModel.shouldProcessAndUploadForNewCollection = false
                // Dismiss sheet first
                activeSheet = nil
                // Then process and upload
                Task {
                    await processPhotosAndUploadForNewCollection()
                }
            }
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .chooseCollection:
                if let uid = userStore.currentUserId {
                    ChooseCollectionView(uid: uid, collectionStore, collectionImageStore)
                        .environment(viewModel)
                        .bottomSheetModifiers()
                }
            case .newCollection:
                NewCollectionDetailsView()
                    .environment(viewModel)
                    .bottomSheetModifiers()
                    .presentationDetents([.fraction(0.999)])
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                ZStack(alignment: .leading) {
                    // Hidden trailing content for balance
                    Button {
                        removeCurrentPhoto()
                    } label: {
                        Text("Remove")
                            .font(.caption.bold())
                            .foregroundStyle(Color.theme.red)
                    }
                    .hidden()
                    
                    // Actual x-icon
                    Button {
                        dismiss()
                    } label: {
                        IconImage(name: "arrow-left", color: .theme.iconPrimary, size: 24)
                    }
                }
            },
            header: {
                VStack(spacing: 2) {
                    Text("Selected Photos")
                        .font(.callout.weight(.semibold))
                        .textPrimary()

                    HStack(spacing: 6) {
                        // Media type badge (LIVE or VIDEO)
                        if let mediaType = currentAssetMediaType {
                            HStack(spacing: 3) {
                                Image(systemName: mediaType == "LIVE" ? "livephoto" : "play.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                Text(mediaType)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(mediaType == "LIVE" ? .yellow : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(.capsule)
                        }

                        Text("\(currentIndex + 1) of \(selectedAssetsArray.count)")
                            .font(.caption)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                }
            },
            trailingIcon: {
                Button {
                    removeCurrentPhoto()
                } label: {
                    Text("Remove")
                        .font(.caption.bold())
                        .foregroundStyle(Color.theme.red)
                }
            }
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - Center Image Preview
    private var centerImagePreview: some View {
        GeometryReader { geometry in
            if !selectedAssetsArray.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(Array(selectedAssetsArray.enumerated()), id: \.element) { index, asset in
                                PhotoGalleryItem(
                                    asset: asset,
                                    geometry: geometry,
                                    zoomScale: Binding(
                                        get: { zoomScales[asset] ?? 1.0 },
                                        set: { zoomScales[asset] = $0 }
                                    ),
                                    dragOffset: Binding(
                                        get: { dragOffsets[asset] ?? .zero },
                                        set: { dragOffsets[asset] = $0 }
                                    ),
                                    isCurrentlyVisible: asset == scrollPosition,
                                    shouldLoad: shouldLoadPhoto(at: index),
                                    viewModel: viewModel,
                                    collectionStore: collectionStore,
                                    onCollectionTap: {
                                        activeSheet = .chooseCollection
                                    }
                                )
                                .containerRelativeFrame(.horizontal)
                                .id(asset)
                            }
                        }
                        .scrollTargetLayout()
                        .offsetX { value in
                            let closestIndex = -Int(round(value / UIScreen.main.bounds.width))
                            let safeIndex = min(max(0, closestIndex), selectedAssetsArray.count - 1)
                            // Only update if index actually changed
                            if safeIndex < selectedAssetsArray.count && safeIndex != currentIndex {
                                currentIndex = safeIndex
                                scrollPosition = selectedAssetsArray[safeIndex]
                                // Reset zoom and drag when actually changing images
                                if let asset = scrollPosition {
                                    zoomScales[asset] = 1.0
                                    dragOffsets[asset] = .zero
                                }
                            }
                        }
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .scrollDisabled(isCurrentImageZoomed)
                    .onAppear {
                        galleryProxy = proxy
                    }
                }
            }
        }
    }

    // MARK: - Bottom Carousel
    private var bottomCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedAssetsArray.enumerated()), id: \.element) { index, asset in
                        CarouselThumbnail(
                            asset: asset,
                            isSelected: index == currentIndex,
                            index: index
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex = index
                                scrollPosition = asset
                                // Reset zoom when changing images
                                zoomScales[asset] = 1.0
                                dragOffsets[asset] = .zero
                                // Scroll gallery to selected image
                                galleryProxy?.scrollTo(asset, anchor: .center)
                            }
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 80)
            .onChange(of: currentIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Upload Button
    private var uploadButton: some View {
        CliqueButton(
            type: .primary,
            text: viewModel.selectedCollectionId == nil ? "Add to collection" : "Upload \(pluralizeWithCount(count: viewModel.selectedAssets.count, singular: "Flick"))",
            fullWidth: true,
            isLoading: isProcessing
        ) {
            handleUpload()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .disabled(isProcessing)
    }
}

// MARK: - Supporting Views

struct CarouselThumbnail: View {
    let asset: PHAsset
    let isSelected: Bool
    let index: Int
    let onTap: () -> Void

    @Environment(PhotoPickerContext.self) var context
    @State private var carouselImage: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = carouselImage ?? context.thumbnailCache[asset] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .roundCorners(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.surfacesElevatedBlur)
                        .frame(width: 60, height: 60)
                }

                // Media type badges
                MediaTypeBadge(asset: asset, style: .carousel)
                    .frame(width: 60, height: 60)

                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.theme.buttonCTA, lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
            }
            .task {
                // Try to use cached thumbnail first, otherwise load it
                if let cached = context.thumbnailCache[asset] {
                    carouselImage = cached
                } else {
                    context.loadCarouselThumbnail(for: asset) { image in
                        carouselImage = image
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

}

struct PhotoGalleryItem: View {
    let asset: PHAsset
    let geometry: GeometryProxy
    @Binding var zoomScale: CGFloat
    @Binding var dragOffset: CGSize
    let isCurrentlyVisible: Bool
    let shouldLoad: Bool
    let viewModel: CreateViewModel
    let collectionStore: CollectionStore
    let onCollectionTap: () -> Void

    @Environment(PhotoPickerContext.self) var context

    /// Whether this asset is a Live Photo
    private var isLivePhoto: Bool {
        asset.isLivePhoto
    }

    /// Whether this asset is a video
    private var isVideo: Bool {
        asset.isVideo
    }

    /// Video duration formatted as string (e.g., "1:23")
    private var videoDuration: String? {
        guard asset.isVideo else { return nil }
        let duration = Int(asset.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            PhotoZoomContainer(
                maxScale: 5.0,
                isInteractive: !asset.isLivePhoto && !isVideo,
                scale: $zoomScale,
                dragOffset: $dragOffset
            ) {
                if isLivePhoto {
                    // Use Live Photo preview for tap-and-hold playback
                    LivePhotoPreviewView(
                        asset: asset,
                        thumbnail: context.thumbnailCache[asset],
                        contentMode: .fit,
                        isVisible: shouldLoad
                    )
                    .frame(maxWidth: geometry.size.width)
                    .frame(maxHeight: geometry.size.height)
                    .id(asset.localIdentifier) // Force recreation when same asset is selected again
                } else if asset.isVideo {
                    // Use VideoPreviewView for videos
                    VideoPreviewView(
                        asset: asset,
                        thumbnail: context.thumbnailCache[asset],
                        contentMode: .fit,
                        isVisible: shouldLoad
                    )
                    .frame(maxWidth: geometry.size.width)
                    .frame(maxHeight: geometry.size.height)
                } else {
                    // Use TwoStageImageLoader for regular photos
                    TwoStageImageLoader(
                        asset: asset,
                        thumbnail: context.thumbnailCache[asset],
                        contentMode: .fit,
                        isVisible: shouldLoad
                    )
                    .frame(maxWidth: geometry.size.width)
                    .frame(maxHeight: geometry.size.height)
                }
            }
            .overlay(alignment: .topLeading) {
                if let cid = viewModel.selectedCollectionClique?.id {
                    CliquePill(cid: cid, type: .newCollection)
                        .padding(16)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let collectionId = viewModel.selectedCollectionId {
                    Button(action: onCollectionTap) {
                        HStack(spacing: 6) {
                            IconImage(name: "collections", color: .theme.iconPrimary, size: 12)
                            
                            if let name = collectionStore.collections[collectionId]?.name {
                                Text(name)
                                    .font(.caption.bold())
                                    .textPrimary()
                            }
                            
                            if viewModel.newCollectionVisibility == .priv {
                                IconImage(name: "lock", color: .theme.iconPrimary, size: 12)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.theme.surfacesPrimary)
                        .roundCorners(32)
                        .padding(16)
                        .contentShape(.rect)
                    }.noHighlight()
                }
            }
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    if zoomScale > 1 {
                        zoomScale = 1.0
                        dragOffset = .zero
                    } else {
                        zoomScale = 2.0
                    }
                }
            }
        }
    }
}
