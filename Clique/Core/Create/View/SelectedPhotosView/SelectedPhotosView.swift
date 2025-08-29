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
    @Environment(CreateViewModel.self) var viewModel
    @Environment(PhotoPickerContext.self) var context
    
    @State var currentIndex: Int = 0
    @State var scrollPosition: PHAsset?
    @State var zoomScales: [PHAsset: CGFloat] = [:]
    @State var dragOffsets: [PHAsset: CGSize] = [:]
    @State var galleryProxy: ScrollViewProxy?
    
    // Convert Set to Array for indexed access
    var selectedAssetsArray: [PHAsset] {
        Array(viewModel.selectedAssets)
    }
    
    // Check if current image is zoomed
    var isCurrentImageZoomed: Bool {
        guard currentIndex < selectedAssetsArray.count else { return false }
        let currentAsset = selectedAssetsArray[currentIndex]
        return (zoomScales[currentAsset] ?? 1.0) > 1.0
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                centerImagePreview
                bottomCarousel
            }
            .primaryBackground()
        }
        .onAppear {
            // Initialize scroll position to first item
            if !selectedAssetsArray.isEmpty {
                scrollPosition = selectedAssetsArray[0]
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
                        IconImage("arrow-left", color: .theme.iconPrimary, size: 24)
                    }
                }
            },
            header: {
                VStack(spacing: 2) {
                    Text("Selected Photos")
                        .font(.callout.weight(.semibold))
                        .textPrimary()
                    Text("\(currentIndex + 1) of \(selectedAssetsArray.count)")
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Center Image Preview
    private var centerImagePreview: some View {
        GeometryReader { geometry in
            if !selectedAssetsArray.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(selectedAssetsArray, id: \.self) { asset in
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
                                    )
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
            .background(Color.theme.surfacesElevatedPrimary)
            .onChange(of: currentIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CarouselThumbnail: View {
    let asset: PHAsset
    let isSelected: Bool
    let index: Int
    let onTap: () -> Void
    
    @Environment(PhotoPickerContext.self) var context
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = context.thumbnailCache[asset] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.surfacesElevatedBlur)
                        .frame(width: 60, height: 60)
                        .onAppear {
                            context.loadThumbnail(for: asset)
                        }
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.theme.buttonCTA, lineWidth: 3)
                        .frame(width: 60, height: 60)
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
    
    @Environment(PhotoPickerContext.self) var context
    
    var body: some View {
        ZStack {
            PhotoZoomContainer(
                maxScale: 5.0,
                scale: $zoomScale,
                dragOffset: $dragOffset
            ) {
                if let image = context.thumbnailCache[asset] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width)
                        .frame(maxHeight: geometry.size.height)
                } else {
                    PhotoPreviewLoader(asset: asset)
                        .frame(maxWidth: geometry.size.width)
                        .frame(maxHeight: geometry.size.height)
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

struct PhotoPreviewLoader: View {
    let asset: PHAsset
    @State private var fullImage: UIImage?
    
    var body: some View {
        Group {
            if let fullImage = fullImage {
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .onAppear {
                        loadFullImage()
                    }
            }
        }
    }
    
    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.fullImage = image
                }
            }
        }
    }
}
