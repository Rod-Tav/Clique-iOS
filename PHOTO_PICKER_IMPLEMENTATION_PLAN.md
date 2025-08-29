# Photo Picker Enhancement Implementation Plan

## Overview
This document outlines the implementation plan for enhancing the custom photos picker with two major features:
1. **Select All** functionality in album detail views
2. **View Selected** overlay with full-screen photo review capability

## Current Architecture Analysis

### Key Components
- **CollectionPhotosPicker.swift**: Main picker with Photos/Albums tabs
- **AlbumPhotosView.swift**: Album detail view showing photos from specific album
- **PhotoPickerContext**: Observable context managing selection state and processing
- **CreateViewModel**: Manages selected assets and processed images
- **PhotoGridView**: Reusable grid component for displaying photos

### Navigation Flow
- Main picker → Album selection → AlbumPhotosView (via CreateFlowDestination.album)
- Uses NavigationStack with typed destinations

## Feature 1: Select All Button in Album Detail View

### Implementation Details

#### Location
- **File**: `AlbumPhotosView.swift`
- **Position**: Trailing icon in TopAppBar (lines 67-70)

#### Requirements
1. Show "Select All" button when no photos selected
2. Show "Deselect All" button when all photos selected
3. Show current selection count when partially selected

#### Code Changes

```swift
// In AlbumPhotosView.swift

@ViewBuilder private func TrailingIcon() -> some View {
    let allSelected = !albumAssets.isEmpty && 
                     albumAssets.allSatisfy { viewModel.selectedAssets.contains($0) }
    
    if viewModel.selectedAssets.isEmpty {
        // No selection - show "Select All"
        Button {
            selectAllPhotos()
        } label: {
            Text("Select All")
                .font(.caption.bold())
                .textPrimary()
        }
    } else if allSelected {
        // All selected - show "Deselect All"
        Button {
            deselectAllPhotos()
        } label: {
            Text("Deselect All")
                .font(.caption.bold())
                .textPrimary()
        }
    } else {
        // Partial selection - show count and "Add" button
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

// Helper functions
private func selectAllPhotos() {
    albumAssets.forEach { asset in
        if !viewModel.selectedAssets.contains(asset) {
            viewModel.selectedAssets.insert(asset)
        }
    }
}

private func deselectAllPhotos() {
    albumAssets.forEach { asset in
        viewModel.removeAsset(asset)
    }
}
```

## Feature 2: View Selected Overlay

### Implementation Strategy

#### Component Architecture
1. **ViewSelectedButton**: Floating overlay button component
2. **SelectedPhotosView**: Full-screen review interface
3. **Integration**: Add to PhotoPickerContainer (parent wrapper)

### 2.1 View Selected Button Overlay

#### Requirements
- Visible when photos are selected (viewModel.selectedAssets.count > 0)
- Persists across all picker states (Photos tab, Albums tab, Album detail)
- Floating position (bottom center with safe area padding)

#### Implementation

```swift
// New file: Components/PhotoGrid/ViewSelectedButton.swift

struct ViewSelectedButton: View {
    @Environment(CreateViewModel.self) var viewModel
    @Binding var showSelectedPhotosView: Bool
    
    var body: some View {
        if !viewModel.selectedAssets.isEmpty {
            Button {
                showSelectedPhotosView = true
            } label: {
                HStack(spacing: 8) {
                    IconImage("images-posts", color: .white, size: 20)
                    Text("View Selected (\(viewModel.selectedAssets.count))")
                        .font(.callout.bold())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.theme.brandPrimary)
                .clipShape(Capsule())
                .shadow(radius: 8, y: 4)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: viewModel.selectedAssets.count)
        }
    }
}
```

#### Integration Points

```swift
// In PhotoPickerContainer.swift

struct PhotoPickerContainer: View {
    @State private var showSelectedPhotosView = false
    
    var body: some View {
        ZStack {
            // Existing picker content
            NavigationStack(path: $tabViewCoordinator.createNavigationPath) {
                // ... existing content
            }
            
            // Overlay button - always on top
            VStack {
                Spacer()
                ViewSelectedButton(showSelectedPhotosView: $showSelectedPhotosView)
                    .padding(.bottom, 20)
            }
        }
        .fullScreenCover(isPresented: $showSelectedPhotosView) {
            SelectedPhotosView()
        }
    }
}
```

### 2.2 SelectedPhotosView Implementation

#### Requirements
1. Full screen cover presentation
2. TopAppBar with X dismiss button and descriptive header
3. Center image preview with zoom capabilities
4. Bottom carousel for image selection
5. Photo deselection capability

#### Component Structure

```swift
// New file: Core/Create/View/SelectedPhotosView/SelectedPhotosView.swift

struct SelectedPhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CreateViewModel.self) var viewModel
    @Environment(PhotoPickerContext.self) var context
    
    @State private var currentIndex: Int = 0
    @State private var zoomScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    
    // Convert Set to Array for indexed access
    private var selectedAssetsArray: [PHAsset] {
        Array(viewModel.selectedAssets)
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
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage("x", color: .theme.iconPrimary, size: 24)
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
                        .foregroundStyle(Color.theme.textError)
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Center Image Preview
    private var centerImagePreview: some View {
        GeometryReader { geometry in
            if !selectedAssetsArray.isEmpty && currentIndex < selectedAssetsArray.count {
                let asset = selectedAssetsArray[currentIndex]
                
                ZoomContainer(
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
                        // Load full res image for preview
                        PhotoPreviewLoader(asset: asset)
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
                                // Reset zoom when changing images
                                zoomScale = 1.0
                                dragOffset = .zero
                            }
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 80)
            .background(Color.theme.surfacesBackgroundSecondary)
            .onChange(of: currentIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func removeCurrentPhoto() {
        guard !selectedAssetsArray.isEmpty && currentIndex < selectedAssetsArray.count else { return }
        
        let assetToRemove = selectedAssetsArray[currentIndex]
        viewModel.removeAsset(assetToRemove)
        
        // Adjust current index if needed
        if selectedAssetsArray.isEmpty {
            dismiss()
        } else if currentIndex >= selectedAssetsArray.count - 1 {
            currentIndex = max(0, selectedAssetsArray.count - 2)
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
                        .fill(Color.theme.surfacesBackgroundTertiary)
                        .frame(width: 60, height: 60)
                        .onAppear {
                            context.loadThumbnail(for: asset)
                        }
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.theme.brandPrimary, lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .buttonStyle(.plain)
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
```

### 2.3 ZoomContainer Implementation

```swift
// New file: Components/Advanced/ZoomContainer.swift

struct ZoomContainer<Content: View>: View {
    let maxScale: CGFloat
    @Binding var scale: CGFloat
    @Binding var dragOffset: CGSize
    let content: Content
    
    @GestureState private var magnifyBy = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    init(
        maxScale: CGFloat = 5.0,
        scale: Binding<CGFloat>,
        dragOffset: Binding<CGSize>,
        @ViewBuilder content: () -> Content
    ) {
        self.maxScale = maxScale
        self._scale = scale
        self._dragOffset = dragOffset
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(scale * magnifyBy)
            .offset(dragOffset)
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        scale = min(max(scale * value, 1.0), maxScale)
                        if scale <= 1.0 {
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                scale > 1.0 ? DragGesture()
                    .onChanged { value in
                        dragOffset = CGSize(
                            width: value.translation.width + dragOffset.width,
                            height: value.translation.height + dragOffset.height
                        )
                    } : nil
            )
    }
}
```

## Implementation Steps

### Phase 1: Select All Button (1-2 hours)
1. Update `AlbumPhotosView.swift` TrailingIcon function
2. Add selectAllPhotos() and deselectAllPhotos() helper functions
3. Test selection/deselection logic

### Phase 2: View Selected Button Overlay (2-3 hours)
1. Create `ViewSelectedButton.swift` component
2. Integrate into `PhotoPickerContainer.swift`
3. Ensure button persists across navigation states
4. Add animations and transitions

### Phase 3: SelectedPhotosView (4-5 hours)
1. Create `SelectedPhotosView.swift` with basic structure
2. Implement TopAppBar with dismiss and remove actions
3. Add center image preview with placeholder loading
4. Implement bottom carousel with thumbnails
5. Add photo removal logic with index management

### Phase 4: Zoom Functionality (2-3 hours)
1. Create `ZoomContainer.swift` component
2. Integrate pinch-to-zoom gesture
3. Add drag gesture for panning when zoomed
4. Implement double-tap to zoom toggle
5. Add PhotoPreviewLoader for full-resolution images

### Phase 5: Testing & Polish (2 hours)
1. Test navigation flow from all entry points
2. Verify selection persistence
3. Test zoom limits and gesture conflicts
4. Ensure smooth animations
5. Handle edge cases (empty selection, single photo)

## Testing Checklist

### Functional Testing
- [ ] Select All works in album detail view
- [ ] Deselect All appears when all photos selected
- [ ] View Selected button appears/disappears correctly
- [ ] View Selected persists across tab changes
- [ ] Full screen cover presents and dismisses properly
- [ ] Photo removal updates UI correctly
- [ ] Carousel scrolls to selected photo
- [ ] Zoom gestures work smoothly
- [ ] Double-tap zoom toggle works

### Edge Cases
- [ ] Empty selection handling
- [ ] Single photo selection
- [ ] Maximum selection limits
- [ ] Memory management with large albums
- [ ] Orientation changes

### Performance
- [ ] Smooth scrolling in carousel
- [ ] Fast image loading
- [ ] No memory leaks
- [ ] Efficient thumbnail caching

## Dependencies

### Existing Components to Reuse
- TopAppBar
- IconImage  
- PhotoGridView (for reference)
- Color.theme system

### New Components Needed
- ViewSelectedButton
- SelectedPhotosView
- ZoomContainer
- CarouselThumbnail
- PhotoPreviewLoader

## Notes for AI Developer

1. **Navigation Context**: The picker is embedded in a CreateNavigationStack, not TabNavigationStack, so be careful with navigation modifiers.

2. **State Management**: All selection state is managed in CreateViewModel which is passed via @Environment.

3. **Photo Processing**: The existing PhotoPickerContext handles thumbnail caching - reuse this for performance.

4. **Styling**: Follow the existing pattern of using semantic colors (Color.theme.x) and standard spacing.

5. **Performance**: For the carousel, only load visible thumbnails. For the main preview, load full resolution on demand.

6. **Gestures**: Be careful with gesture conflicts between zoom, pan, and scroll gestures.

## Estimated Total Time: 10-15 hours

This includes implementation, testing, and polish for production-ready code.
