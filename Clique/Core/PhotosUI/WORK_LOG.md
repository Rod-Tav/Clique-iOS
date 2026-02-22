# PhotosUI Implementation Work Log

## Overview
Implemented a 4-phase plan to add tap-to-detail navigation, unified photo abstraction, shared album main view, and legacy migration tab to the PhotosUI feature.

---

## Phase 1: Tap-to-Detail Hero Animation

### New Files
1. **`ViewModel/SharedAlbumCoordinator.swift`**
   - Minimal `ImageDetailCoordinator` conformance for shared albums
   - Follows `UserFlicksDetailCoordinator` pattern
   - Properties: `selectedImageId`, `detailScrollPosition`, `detailIndicatorPosition`, `canInteract`, etc.
   - Marked `@available(iOS 26, *)`

2. **`View/SharedAlbumPhotoDetailView.swift`**
   - Full-screen photo detail carousel for PHAssets
   - Horizontal ScrollView carousel with scroll-position sync
   - Bottom thumbnail indicator with selected-item enlargement
   - Full-resolution image loading via PHImageManager (thumbnail first, then full-res)
   - Drag-to-dismiss gesture using `compatibleDragGesture` + `GestureConstants`
   - DEST anchor preference for hero animation
   - Top bar with back button and creation date
   - Black background with opacity tied to drag progress

3. **`View/PhotosGridCell.swift`** — added `TappablePhotosGridCell`
   - New variant wrapping `PhotosGridCell` with `.heroSourceLocal()` modifier and onTap callback

### Modified Files
4. **`Helpers/Hero/HeroCoordinator.swift`**
   - Added `heroIdentifier: String?` and `heroImage: UIImage?` for identifier-based (non-URL) hero support
   - Added computed `activeHeroKey` property (returns URL or identifier)
   - Updated `resetAnimationProperties()` to clear new fields

5. **`Helpers/Hero/HeroOverlayModifier.swift`**
   - Added `HeroSourceLocalModifier` struct for identifier-based hero sources
   - Added `.heroSourceLocal(identifier:image:action:)` view extension
   - Updated `HeroOverlayModifier` to use `activeHeroKey` instead of just URL-based matching

6. **`Core/Collection/View/HeroLayer.swift`**
   - Added branch to render local UIImage when `heroImage` is set (identifier-based path)
   - Existing Kingfisher URL-based path preserved untouched

7. **`Core/PhotosUI/View/SharedAlbumDetailView.swift`** (renamed from original)
   - Added `@State var coordinator = SharedAlbumCoordinator()`
   - Added `@State var heroCoordinator = HeroCoordinator()`
   - Added `.disabled(!coordinator.canInteract)` on ScrollView
   - Added `.heroOverlay { SharedAlbumPhotoDetailView(assets:) }` with coordinator environment
   - Added `.environment(heroCoordinator)`
   - Swapped `PhotosGridCell` → `TappablePhotosGridCell` with identifier and onTap

8. **`Core/PhotosUI/View/SharedLibraryGridView.swift`**
   - Same hero wiring as SharedAlbumDetailView (coordinator, heroCoordinator, heroOverlay, TappablePhotosGridCell)

---

## Phase 2: Unified Photo Abstraction Layer

### New Files
1. **`Model/DisplayablePhoto.swift`**
   - Protocol unifying PHAsset and CollectionImage display
   - Properties: `id`, `creationDate`, `isVideo`, `isLivePhoto`, `mediaUrls`, `localThumbnail`, `hasSocialFeatures`

2. **`Model/SharedAlbumPhoto.swift`**
   - `@available(iOS 26, *)` struct wrapping PHAsset + cached thumbnail
   - Conforms to `DisplayablePhoto`
   - `hasSocialFeatures = false`, `mediaUrls = nil`, `localThumbnail` = cached UIImage

3. **`Model/PhotoDataSource.swift`**
   - `PhotoDataSource` protocol: `photoIds`, `displayablePhoto(for:)`, `isFullyLoaded`, `loadInitial()`, `loadMore()`
   - `SharedAlbumPhotoDataSource` — backed by PHAssets, always fully loaded
   - `CliquePhotoDataSource` — backed by `CollectionImagesPaginationViewModel` + `CollectionImageStore`

### Modified Files
4. **`Model/ClCollection.swift`**
   - Added `DisplayablePhoto` conformance extension to `CollectionImage`
   - Maps: `date` → `creationDate`, `imageUrl` → `mediaUrls`, `hasSocialFeatures = true`, `localThumbnail = nil`

---

## Phase 3: SharedAlbumMainView (CollectionMainView Pattern)

### New Files
1. **`View/SharedAlbumMainView.swift`**
   - CollectionMainView-style layout for viewing a single shared album
   - Cover photo header (300pt) with album title and photo count
   - Back button with dismiss
   - 3-column LazyVGrid photo grid
   - Hero overlay → SharedAlbumPhotoDetailView
   - Scroll-based prefetching with PHCachingImageManager
   - Loading shimmer placeholders and empty state

### Modified Files
2. **`View/SharedAlbumsListView.swift`**
   - Changed navigation destination from `SharedAlbumDetailView` to `SharedAlbumMainView(assetCollection: collection)`

---

## Phase 4: Legacy Tab for S3 Migration

### New Files
1. **`View/LegacyCollectionsView.swift`**
   - Fetches user's Clique collections via `CollectionService.getCollectionsByUser`
   - 2-column grid with Kingfisher cover images
   - NavigationLink to existing `CollectionMainView`
   - "Migrate to iCloud" button per collection using PhotoMigrationHelper

2. **`Helpers/PhotoMigrationHelper.swift`**
   - Downloads S3 images via URLSession
   - Saves to Photo Library via `PHPhotoLibrary.shared().performChanges`
   - Creates/finds named album
   - Tracks progress with `migratedCount` / `totalCount`

### Modified Files
3. **`View/PhotosTabView.swift`**
   - Added third tab: `Tab("Legacy", systemImage: "clock.arrow.circlepath") { NavigationStack { LegacyCollectionsView() } }`

---

## Bug Fixes Applied

### 1. `@MainActor` isolation error (PhotoDataSource.swift:82)
- **Error**: `Main actor-isolated property 'images' can not be referenced from a nonisolated context`
- **Fix**: Added `@MainActor` to `CliquePhotoDataSource` class declaration since it accesses `CollectionImageStore` (which is `@MainActor`)

### 2. Optional unwrapping errors (SharedAlbumPhotoDetailView.swift:113, 208, 244)
- **Error**: `Value of optional type 'PHAsset?' must be unwrapped to a value of type 'PHAsset'`
- **Cause**: `assets.first { ... }` returns `PHAsset?` but `thumbnailCache` subscript expects `PHAsset`
- **Fix**: Changed all three occurrences from:
  ```swift
  heroCoordinator.heroImage = sharedData.thumbnailCache[assets.first { $0.localIdentifier == id }]
  ```
  to:
  ```swift
  if let matched = assets.first(where: { $0.localIdentifier == id }) {
      heroCoordinator.heroImage = sharedData.thumbnailCache[matched]
  }
  ```

---

## Complete File List

### New Files (9)
- `Core/PhotosUI/ViewModel/SharedAlbumCoordinator.swift`
- `Core/PhotosUI/View/SharedAlbumPhotoDetailView.swift`
- `Core/PhotosUI/View/SharedAlbumMainView.swift`
- `Core/PhotosUI/Model/DisplayablePhoto.swift`
- `Core/PhotosUI/Model/SharedAlbumPhoto.swift`
- `Core/PhotosUI/Model/PhotoDataSource.swift`
- `Core/PhotosUI/View/LegacyCollectionsView.swift`
- `Core/PhotosUI/Helpers/PhotoMigrationHelper.swift`
- `Core/PhotosUI/View/PhotosGridCell.swift` (TappablePhotosGridCell added)

### Modified Files (8)
- `Helpers/Hero/HeroCoordinator.swift`
- `Helpers/Hero/HeroOverlayModifier.swift`
- `Core/Collection/View/HeroLayer.swift`
- `Core/PhotosUI/View/SharedAlbumDetailView.swift`
- `Core/PhotosUI/View/SharedLibraryGridView.swift`
- `Core/PhotosUI/View/SharedAlbumsListView.swift`
- `Core/PhotosUI/View/PhotosTabView.swift`
- `Model/ClCollection.swift`
