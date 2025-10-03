# Live Photos and Videos Implementation Plan

**Date**: January 2025
**Last Updated**: January 31, 2025
**Status**: Phase 3 Complete - Backend Integration In Progress
**Scope**: iOS Frontend Refactor for Live Photos, Videos, and Backend-Managed Quality Variants

---

## 📊 Implementation Status

### ✅ Completed Phases

**Phase 1: Foundation & Data Models** - ✅ COMPLETE
- Created `MediaType` enum (PHOTO, LIVE, VIDEO)
- Renamed `PhotoUrls` → `MediaUrls` with enhanced API
- Updated `CollectionImage` with video URLs and media type
- Updated `ClCollection`, `User`, `Clique` models
- Updated all DTOs (CollectionDTO, UserDTO, CliqueDTO, MediaUrlsDTO)
- Global find & replace: 44 files updated from PhotoUrls to MediaUrls

**Phase 2: Photo Picker & Live Photo Support** - ✅ COMPLETE
- Created `LivePhotoHelper.swift` with extraction and detection
- Updated `PhotoProcessingHelper` to detect Live Photos concurrently
- Updated `CreateViewModel` with Live Photo component storage
- Added Live Photo badges to photo picker grid

**Phase 3: Upload Flow Enhancement** - ✅ COMPLETE
- Created `VideoUploadHelper.swift` for video preparation
- Updated `PhotoProcessingHelper` for Live Photo upload preparation
- Updated `CreateViewModel` with video variant storage
- Updated `TabViewModel` upload functions with video support
- **CRITICAL**: Implemented streaming video uploads (memory optimization)
  - LivePhotoHelper returns temp file URL instead of loading Data
  - Added streaming MD5 calculation (1MB buffer)
  - Created `uploadVideoFromFile()` using URLSession streaming
  - Memory impact: 50-200MB per video → ~1MB buffer
  - Matches Instagram/YouTube/Netflix performance standards

**Backend Upload Status Integration** - 🔄 IN PROGRESS (New Requirement)
- Backend now tracks upload status automatically (PENDING, FAILED, COMPLETED)
- OpenAPI updated with `uploadStatus` field
- Frontend needs to stop marking uploads and show status in UI

### 🚧 Remaining Phases

**Phase 4: Display & Playback Support** - ⏳ NOT STARTED
- Live Photo view component with playback
- Video player component
- Collection detail view updates
- Grid view media type badges

**Phase 5: Store Updates & URL Management** - ⏳ NOT STARTED
- CollectionImageStore video URL management
- CollectionStore updates

**Phase 6: Testing & Validation** - ⏳ NOT STARTED
- Test plan execution
- Mock data updates
- Comprehensive testing

**Phase 7: UI/UX Enhancements** - ⏳ NOT STARTED
- Upload progress indicators
- Media type filters

**Phase 8: Documentation & Cleanup** - ⏳ NOT STARTED
- CLAUDE.md updates
- DocC documentation
- Code cleanup

---

## 🎯 Current Priority: Backend Upload Status Integration

### Context
The backend has been updated to automatically track upload status. The frontend no longer needs to mark images as uploaded. Instead, the backend provides status via the `uploadStatus` field:
- `PENDING`: Image uploaded, backend processing
- `FAILED`: Processing or upload failed
- `COMPLETED`: Fully processed and ready

### Required Changes

1. **Regenerate OpenAPI Types**
   - Build Xcode project to generate Swift types from updated openapi.yaml
   - Adds `uploadStatus: UploadStatus?` to `Components.Schemas.CollectionItem`

2. **Update Domain Model** (`Model/ClCollection.swift`)
   - Add `UploadStatus` enum
   - Add `uploadStatus: UploadStatus?` to `CollectionImage`

3. **Update DTO Mapping** (`Model/Data/CollectionDTO.swift`)
   - Map `uploadStatus` field in `mapToCollectionImage()`
   - Add `mapToUploadStatus()` helper

4. **Remove Upload Marking** (`Utils/Coordinators/TabViewModel.swift`)
   - Remove `CollectionService.markCollectionImagesAsUploaded()` calls
   - Keep failure tracking for retry UI

5. **Create Upload Status UI**
   - New component: `UploadStatusOverlay.swift`
   - View extension: `.overlayUploadStatus()`
   - Apply to `CollectionMainView.swift` image cells

### Files to Modify
- `Frontend/iOS/Clique/Clique/Model/ClCollection.swift`
- `Frontend/iOS/Clique/Clique/Model/Data/CollectionDTO.swift`
- `Frontend/iOS/Clique/Clique/Utils/Coordinators/TabViewModel.swift`
- `Frontend/iOS/Clique/Clique/Components/Advanced/UploadStatusOverlay.swift` (NEW)
- `Frontend/iOS/Clique/Clique/Helpers/Extensions/ViewExtensions.swift`
- `Frontend/iOS/Clique/Clique/Core/Collection/View/CollectionMainView.swift`

---

## Executive Summary

This document outlines the comprehensive implementation plan for bringing **Live Photos** and **Videos** into the Clique iOS app, along with transitioning responsibility for photo quality variant generation from the frontend to the backend.

### Key Changes from OpenAPI Analysis

The backend now supports:
1. **Three media types**: `PHOTO` (standard), `LIVE` (Live Photo with still + video), `VIDEO` (standalone video)
2. **Three-tier quality system**: Full resolution (`url`), medium quality (`medQualityUrl`), and thumbnail (`lowQualityUrl`)
3. **Dual component storage**: Separate photo and video components with independent IDs and URL sets
4. **Backend quality management**: Backend expects clients to provide pre-generated quality variants

### Current iOS Architecture

**Data Models**:
- `PhotoUrls` - Currently stores 3 quality URLs (high, medium, low)
- `CollectionImage` - Image with metadata, currently photo-only
- `ClCollection` - Collection of images

**Upload Flow**:
1. Photo selection (Camera or Library via CollectionPhotosPicker)
2. Processing in `PhotoProcessingHelper.processSelectedPhotosForUpload()`
3. Generate 3 quality variants per image
4. Create `PhotoDatePair` with metadata
5. Upload to `/collection/upload` endpoint
6. Receive presigned S3 URLs for each variant
7. Upload to S3 via `PhotoHelper.uploadImages()`
8. Mark uploaded via `/collection/markUploaded`

**Display Flow**:
- Kingfisher-based image loading with multi-tier caching
- `GenericAsyncImage` with performance and standard modes
- Progressive quality loading (low → medium → high)
- Grid optimization with `GridAsyncImage`

---

## Phase 1: Foundation & Data Models

### 1.1 Create New Models and Enums

**Priority**: Critical
**Estimated Effort**: 2-3 hours

#### Create `MediaType.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/MediaType.swift`

```swift
/// Media type enum matching backend schema
enum MediaType: String, Codable, Hashable, Sendable {
    case PHOTO
    case LIVE
    case VIDEO

    var displayName: String {
        switch self {
        case .PHOTO: return "Photo"
        case .LIVE: return "Live Photo"
        case .VIDEO: return "Video"
        }
    }

    var iconName: String {
        switch self {
        case .PHOTO: return "photo"
        case .LIVE: return "livephoto"
        case .VIDEO: return "video.fill"
        }
    }
}
```

#### Update `PhotoUrls.swift` → `MediaUrls.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Helpers/MediaUrls.swift`

**Action**: Rename and enhance with better API surface

```swift
/// Represents URLs for different quality variants of media (photo or video)
struct MediaUrls: Codable, Hashable, Sendable {
    /// Full resolution URL
    var url: String?
    /// Medium quality URL (for feed display)
    var medQualityUrl: String?
    /// Low quality/thumbnail URL (for grid views)
    var lowQualityUrl: String?

    /// Initialize with URLs for each quality level
    init(url: String? = nil, medQualityUrl: String? = nil, lowQualityUrl: String? = nil) {
        self.url = url
        self.medQualityUrl = medQualityUrl
        self.lowQualityUrl = lowQualityUrl
    }

    /// All quality levels in fallback order (high → medium → low)
    var urls: [String?] {
        [url, medQualityUrl, lowQualityUrl]
    }

    /// All valid, non-nil URLs in fallback order
    var validUrls: [URL] {
        urls.compactMap { $0 }.compactMap(URL.init)
    }

    /// Best available URL (first non-nil in quality order)
    var bestUrl: URL? {
        validUrls.first
    }

    /// Get URL for specific quality with fallback
    func url(for quality: ImageQuality) -> URL? {
        switch quality {
        case .high:
            return validUrls.first
        case .medium:
            return URL(string: medQualityUrl ?? "") ?? validUrls.first
        case .low:
            return URL(string: lowQualityUrl ?? "") ?? URL(string: medQualityUrl ?? "") ?? validUrls.first
        }
    }
}
```

### 1.2 Update Core Data Models

#### Update `CollectionImage` Model
**Location**: `Frontend/iOS/Clique/Clique/Model/ClCollection.swift`

```swift
struct CollectionImage: Identifiable, Hashable, Codable {
    let id: String
    var owner: User?

    // PHOTO component (always present)
    var imageUrl: MediaUrls? = nil
    var uiImage: UIImage? = nil

    // VIDEO component (present for LIVE and VIDEO types)
    var videoUrls: MediaUrls? = nil
    var videoId: String? = nil

    // Media type indicator
    var mediaType: MediaType = .PHOTO

    var date: Date
    var numLikes: Int = 0
    var numComments: Int = 0
    var numTaggedMembers: Int = 0
    var hasLiked: Bool = false

    // Computed properties
    var isLivePhoto: Bool {
        mediaType == .LIVE
    }

    var isVideo: Bool {
        mediaType == .VIDEO
    }

    var hasVideoComponent: Bool {
        videoUrls != nil
    }
}

extension CollectionImage {
    enum CodingKeys: String, CodingKey {
        case id, owner, imageUrl, videoUrls, videoId, mediaType
        case date, numLikes, numComments, numTaggedMembers, hasLiked
        // intentionally exclude `uiImage`
    }
}
```

#### Update `ClCollection` Model
**Location**: `Frontend/iOS/Clique/Clique/Model/ClCollection.swift`

```swift
struct ClCollection: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String = ""
    var userId: String = ""
    var cliqueId: String = ""
    let creation: Date
    var images: [CollectionImage]
    var coverPhoto: MediaUrls? = nil  // Changed from PhotoUrls
    var visibility: Visibility
    var numFlicks: Int = 0

    var mostLikedImage: String?

    // Computed properties for media types
    var hasLivePhotos: Bool {
        images.contains { $0.mediaType == .LIVE }
    }

    var hasVideos: Bool {
        images.contains { $0.mediaType == .VIDEO }
    }

    var mediaTypeCounts: (photos: Int, livePhotos: Int, videos: Int) {
        let photos = images.filter { $0.mediaType == .PHOTO }.count
        let livePhotos = images.filter { $0.mediaType == .LIVE }.count
        let videos = images.filter { $0.mediaType == .VIDEO }.count
        return (photos, livePhotos, videos)
    }
}
```

#### Update `User` Model
**Location**: `Frontend/iOS/Clique/Clique/Model/User.swift`

```swift
// Update profilePic property
struct User: Identifiable, Hashable, Codable {
    // ... existing properties ...
    var profilePic: MediaUrls?  // Changed from PhotoUrls
    // ... rest of properties ...
}
```

#### Update `Clique` Model
**Location**: `Frontend/iOS/Clique/Clique/Model/Clique.swift`

```swift
// Update banner and profile pic properties
struct Clique: Identifiable, Hashable, Codable {
    // ... existing properties ...
    var cliqueBanner: MediaUrls?  // Changed from PhotoUrls
    var cliqueProfilePic: MediaUrls?  // Changed from PhotoUrls
    // ... rest of properties ...
}
```

### 1.3 Update DTOs

#### Rename and Update `PhotoUrlsDTO.swift` → `MediaUrlsDTO.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Data/MediaUrlsDTO.swift`

```swift
import Foundation

func mapToMediaUrls(_ urls: Components.Schemas.MediaUrls) -> MediaUrls {
    return MediaUrls(
        url: urls.url,
        medQualityUrl: urls.medQualityUrl,
        lowQualityUrl: urls.lowQualityUrl
    )
}

// Backward compatibility during migration
typealias PhotoUrls = MediaUrls
func mapToPhotoUrls(_ urls: Components.Schemas.MediaUrls) -> MediaUrls {
    return mapToMediaUrls(urls)
}
```

#### Update `CollectionDTO.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Data/CollectionDTO.swift`

```swift
import Foundation

// Update mapping function name
func mapToPhotoVideoDate(photo: Components.Schemas.PhotoDataNoPath?, video: Components.Schemas.VideoDataNoPath?, mediaType: MediaType, date: Date) -> Components.Schemas.PhotoVideoDate {
    return Components.Schemas.PhotoVideoDate(
        photo: photo,
        video: video,
        mediaType: mapFromMediaType(mediaType),
        dateCreated: convertFromDate(date)
    )
}

// New helper to map MediaType to schema
func mapFromMediaType(_ mediaType: MediaType) -> Components.Schemas.MediaType {
    switch mediaType {
    case .PHOTO: return .PHOTO
    case .LIVE: return .LIVE
    case .VIDEO: return .VIDEO
    }
}

// New helper to map from schema MediaType
func mapToMediaType(_ mediaType: Components.Schemas.MediaType) -> MediaType {
    switch mediaType {
    case .PHOTO: return .PHOTO
    case .LIVE: return .LIVE
    case .VIDEO: return .VIDEO
    }
}

// Update CollectionImage mapping
func mapToCollectionImage(_ data: Components.Schemas.UrlCollectionItem) -> CollectionImage {
    return CollectionImage(
        id: data.collectionItem!.collectionItemId!,
        owner: mapToUser(data.collectionItem!.user!),
        imageUrl: data.urls != nil ? mapToMediaUrls(data.urls!) : nil,
        videoUrls: data.videoUrls != nil ? mapToMediaUrls(data.videoUrls!) : nil,
        videoId: data.collectionItem!.videoId,
        mediaType: data.collectionItem!.mediaType != nil ? mapToMediaType(data.collectionItem!.mediaType!) : .PHOTO,
        date: convertToDate(data.collectionItem!.dateCreated!),
        numLikes: data.collectionItem!.likes!,
        numComments: data.collectionItem!.commentCount ?? 0,
        numTaggedMembers: 0,
        hasLiked: data.isLiked ?? false
    )
}

// Update Collection mapping
func mapToCollection(collectionData: Components.Schemas.CollectionData, images: [CollectionImage]) -> ClCollection {
    return ClCollection(
        id: collectionData.collectionDataId!,
        name: collectionData.name == "" ? "Untitled Collection" : collectionData.name!,
        description: collectionData.description!,
        userId: collectionData.createdBy!,
        cliqueId: collectionData.clique!,
        creation: convertToDate(collectionData.dateCreated),
        images: images,
        coverPhoto: collectionData.coverPhoto == nil ? nil : mapToMediaUrls(collectionData.coverPhoto!),
        visibility: mapToVisibility(collectionData.privacySetting!),
        numFlicks: collectionData.picCount!
    )
}
```

#### Update `UserDTO.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Data/UserDTO.swift`

```swift
// Update User mapping to use MediaUrls
func mapToUser(_ userDto: Components.Schemas.User) -> User {
    return User(
        id: userDto.id!,
        username: userDto.username!,
        firstName: userDto.firstName,
        lastName: userDto.lastName,
        profilePic: userDto.profilePic != nil ? mapToMediaUrls(userDto.profilePic!) : nil,
        // ... rest of mapping ...
    )
}
```

#### Update `CliqueDTO.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Data/CliqueDTO.swift`

```swift
// Update Clique mapping to use MediaUrls
func mapToClique(_ cliqueDto: Components.Schemas.Clique) -> Clique {
    return Clique(
        id: cliqueDto.cliqueDataId!,
        name: cliqueDto.name!,
        bio: cliqueDto.bio,
        cliqueBanner: cliqueDto.cliqueBanner != nil ? mapToMediaUrls(cliqueDto.cliqueBanner!) : nil,
        cliqueProfilePic: cliqueDto.cliqueProfilePic != nil ? mapToMediaUrls(cliqueDto.cliqueProfilePic!) : nil,
        // ... rest of mapping ...
    )
}
```

### 1.4 Global Find & Replace

**Action**: Update all references from `PhotoUrls` to `MediaUrls`

**Files to update** (44 files found in grep):
- All Kingfisher image components
- All view files using image URLs
- Store files (UserStore, CliqueStore, CollectionStore)
- Helper files

**Strategy**: Use Xcode's Find & Replace in Workspace
- Find: `PhotoUrls`
- Replace: `MediaUrls`
- Review each change manually

**Note**: Keep the `typealias PhotoUrls = MediaUrls` in `MediaUrlsDTO.swift` for backward compatibility during transition.

---

## Phase 2: Photo Picker & Live Photo Support

### 2.1 Create Live Photo Detection Helper

**Priority**: Critical
**Estimated Effort**: 3-4 hours

#### Create `LivePhotoHelper.swift`
**Location**: `Frontend/iOS/Clique/Clique/Helpers/Photos/LivePhotoHelper.swift`

```swift
import Foundation
import Photos
import UIKit
import AVFoundation

struct LivePhotoHelper {

    // MARK: - Live Photo Detection

    /// Check if a PHAsset is a Live Photo
    static func isLivePhoto(_ asset: PHAsset) -> Bool {
        if #available(iOS 9.1, *) {
            return (asset.mediaSubtypes.contains(.photoLive))
        }
        return false
    }

    // MARK: - Live Photo Component Extraction

    /// Extract still image and video from a Live Photo asset
    /// Returns: (stillImageData, videoData, stillImage, creationDate) or nil if extraction fails
    static func extractLivePhotoComponents(from asset: PHAsset) async throws -> (stillImageData: Data, videoData: Data, stillImage: UIImage, creationDate: Date) {
        guard isLivePhoto(asset) else {
            throw LivePhotoError.notALivePhoto
        }

        // Extract still image
        let (stillImageData, stillImage) = try await extractStillImage(from: asset)

        // Extract video component
        let videoData = try await extractVideo(from: asset)

        let creationDate = asset.creationDate ?? Date()

        return (stillImageData, videoData, stillImage, creationDate)
    }

    /// Extract the still image from a Live Photo asset
    private static func extractStillImage(from asset: PHAsset) async throws -> (Data, UIImage) {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, dataUTI, orientation, info in
                if let data = data, let image = UIImage(data: data) {
                    continuation.resume(returning: (data, image))
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: LivePhotoError.failedToExtractStillImage)
                }
            }
        }
    }

    /// Extract the video component from a Live Photo asset
    private static func extractVideo(from asset: PHAsset) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, audioMix, info in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: LivePhotoError.failedToExtractVideo)
                    return
                }

                do {
                    let videoData = try Data(contentsOf: urlAsset.url)
                    continuation.resume(returning: videoData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Video Metadata Extraction

    /// Get video metadata (duration, dimensions, file size)
    static func getVideoMetadata(from videoData: Data) -> VideoMetadata? {
        // Write to temp file to analyze with AVAsset
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")

        do {
            try videoData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let asset = AVURLAsset(url: tempURL)
            let duration = asset.duration.seconds

            guard let track = asset.tracks(withMediaType: .video).first else {
                return nil
            }

            let size = track.naturalSize.applying(track.preferredTransform)
            let dimensions = CGSize(width: abs(size.width), height: abs(size.height))

            return VideoMetadata(
                duration: duration,
                dimensions: dimensions,
                fileSize: videoData.count
            )
        } catch {
            print("Error getting video metadata: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

struct VideoMetadata {
    let duration: TimeInterval
    let dimensions: CGSize
    let fileSize: Int

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

enum LivePhotoError: Error, LocalizedError {
    case notALivePhoto
    case failedToExtractStillImage
    case failedToExtractVideo
    case invalidVideoData

    var errorDescription: String? {
        switch self {
        case .notALivePhoto:
            return "The selected asset is not a Live Photo"
        case .failedToExtractStillImage:
            return "Failed to extract still image from Live Photo"
        case .failedToExtractVideo:
            return "Failed to extract video component from Live Photo"
        case .invalidVideoData:
            return "The video data is invalid or corrupted"
        }
    }
}
```

### 2.2 Update Photo Processing Helper

#### Update `PhotoProcessingHelper.swift`
**Location**: `Frontend/iOS/Clique/Clique/Core/Create/Helpers/PhotoProcessingHelper.swift`

**Add new function to detect and process Live Photos**:

```swift
/// Process assets including Live Photos, detecting media type automatically
static func processAssetsWithMediaType(
    assets: [PHAsset],
    viewModel: CreateViewModel,
    clearExistingData: Bool = false,
    onProgress: @MainActor @escaping (Int, Int) -> Void = { _, _ in },
    onError: @MainActor @escaping (Error) -> Void,
    onComplete: @MainActor @escaping () -> Void
) async {
    // Clear existing data if requested
    if clearExistingData {
        await MainActor.run {
            viewModel.selectedImages.removeAll()
            viewModel.selectedImagesDates.removeAll()
            viewModel.selectedAssets.removeAll()
            viewModel.processedAssets.removeAll()
            viewModel.processedImageData.removeAll()
            viewModel.livePhotoComponents.removeAll()  // New
        }
    }

    typealias ProcessedAssetResult = (
        index: Int,
        asset: PHAsset,
        image: UIImage?,
        date: Date,
        mediaType: MediaType,
        livePhotoData: LivePhotoComponentData?,
        error: Error?
    )

    await withTaskGroup(of: ProcessedAssetResult.self) { group in
        for (index, asset) in assets.enumerated() {
            group.addTask {
                do {
                    // Check if it's a Live Photo
                    if LivePhotoHelper.isLivePhoto(asset) {
                        let (stillData, videoData, stillImage, date) = try await LivePhotoHelper.extractLivePhotoComponents(from: asset)

                        let liveData = LivePhotoComponentData(
                            stillImageData: stillData,
                            videoData: videoData,
                            stillImage: stillImage
                        )

                        return (index, asset, stillImage, date, .LIVE, liveData, nil)
                    } else {
                        // Regular photo
                        let (_, image) = try await loadImageFromAsset(asset)
                        return (index, asset, image, asset.creationDate ?? Date(), .PHOTO, nil, nil)
                    }
                } catch {
                    print("Failed to load asset at index \(index): \(error)")
                    return (index, asset, nil, asset.creationDate ?? Date(), .PHOTO, nil, error)
                }
            }
        }

        // Collect results
        var results: [ProcessedAssetResult] = []
        let totalAssets = assets.count
        var processedCount = 0

        for await result in group {
            results.append(result)
            processedCount += 1

            let currentCount = processedCount
            await MainActor.run {
                onProgress(currentCount, totalAssets)
            }
        }

        // Sort and update view model
        results.sort { $0.index < $1.index }

        await MainActor.run {
            for result in results {
                if let error = result.error {
                    onError(error)
                    continue
                }

                guard let image = result.image else { continue }

                viewModel.selectedImages.append(image)
                viewModel.selectedImagesDates.append(result.date)
                viewModel.selectedAssets.insert(result.asset)
                viewModel.processedAssets.insert(result.asset)
                viewModel.processedImageData[result.asset.localIdentifier] = (image, result.date)

                // Store Live Photo data if present
                if let liveData = result.livePhotoData {
                    viewModel.livePhotoComponents[result.asset.localIdentifier] = liveData
                }
            }

            onComplete()
        }
    }
}
```

### 2.3 Update CreateViewModel

#### Update `CreateViewModel.swift`
**Location**: `Frontend/iOS/Clique/Clique/Core/Create/ViewModel/CreateViewModel.swift`

**Add new properties**:

```swift
@Observable final class CreateViewModel {
    // ... existing properties ...

    // Live Photo support
    var livePhotoComponents: [String: LivePhotoComponentData] = [:]
    var selectedMediaTypes: [MediaType] = []

    // Video support (for future standalone video uploads)
    var selectedVideoURLs: [URL] = []

    // ... rest of class ...
}

// New supporting type
struct LivePhotoComponentData {
    let stillImageData: Data
    let videoData: Data
    let stillImage: UIImage
}
```

### 2.4 Update Photo Picker Views

#### Update `CollectionPhotosPickerFunctions.swift`
**Location**: `Frontend/iOS/Clique/Clique/Core/Create/View/CollectionPhotosPicker/CollectionPhotosPickerFunctions.swift`

**Update asset processing to detect Live Photos**:

```swift
// Add Live Photo badge to grid thumbnails
// In the asset grid view, add badge overlay for Live Photos

func assetThumbnail(for asset: PHAsset) -> some View {
    ZStack(alignment: .topLeading) {
        // Existing thumbnail view

        // Live Photo badge
        if LivePhotoHelper.isLivePhoto(asset) {
            Image(systemName: "livephoto")
                .font(.caption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(4)
        }
    }
}
```

---

## Phase 3: Upload Flow Enhancement

### 3.1 Create Video Upload Helper

**Priority**: Critical
**Estimated Effort**: 3-4 hours

#### Create `VideoUploadHelper.swift`
**Location**: `Frontend/iOS/Clique/Clique/Helpers/Photos/VideoUploadHelper.swift`

```swift
import Foundation

struct VideoUploadHelper {

    /// Prepare video data for upload (no quality variants needed - backend handles it)
    static func prepareVideoForUpload(_ videoData: Data) -> PreparedVideoVariant? {
        // Video uploads only need base video - backend generates variants
        let contentType = "video/quicktime"  // or video/mp4
        let contentLength = Int64(videoData.count)

        let params = Components.Schemas.UploadVideoParams(
            contentType: contentType,
            contentLength: contentLength
        )

        return PreparedVideoVariant(
            data: videoData,
            params: params
        )
    }

    /// Create VideoDataNoPath from prepared video
    static func createVideoDataNoPath(from variant: PreparedVideoVariant) -> Components.Schemas.VideoDataNoPath {
        return Components.Schemas.VideoDataNoPath(
            baseVideo: variant.params
        )
    }
}

struct PreparedVideoVariant {
    let data: Data
    let params: Components.Schemas.UploadVideoParams
}
```

### 3.2 Update Photo Processing for Upload

#### Update `PhotoProcessingHelper.swift` - Add Live Photo Upload Preparation
**Location**: `Frontend/iOS/Clique/Clique/Core/Create/Helpers/PhotoProcessingHelper.swift`

```swift
/// Process selected photos AND Live Photos for upload
static func processSelectedPhotosForUpload(viewModel: CreateViewModel) async {
    viewModel.photoDatePairs.removeAll()
    viewModel.preparedImageVariants.removeAll()

    let imagesToProcess = viewModel.selectedImages
    let datesToProcess = viewModel.selectedImagesDates
    let assetsToProcess = Array(viewModel.selectedAssets)
    let livePhotoData = viewModel.livePhotoComponents

    typealias ProcessResult = (
        index: Int,
        photoVideoDate: Components.Schemas.PhotoVideoDate?,
        imageVariants: (high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)?,
        videoVariant: PreparedVideoVariant?,
        error: Error?
    )

    await withTaskGroup(of: ProcessResult.self) { group in
        for (index, image) in imagesToProcess.enumerated() {
            group.addTask {
                let date = index < datesToProcess.count ? datesToProcess[index] : Date()
                let asset = index < assetsToProcess.count ? assetsToProcess[index] : nil

                // Check if this is a Live Photo
                if let asset = asset,
                   let liveData = livePhotoData[asset.localIdentifier] {
                    // Process Live Photo
                    return processLivePhoto(
                        index: index,
                        stillImage: image,
                        liveData: liveData,
                        date: date
                    )
                } else {
                    // Process regular photo
                    return processRegularPhoto(
                        index: index,
                        image: image,
                        date: date
                    )
                }
            }
        }

        // Collect results
        var results: [ProcessResult] = []
        for await result in group {
            results.append(result)
        }

        // Sort and append to viewModel
        results.sort { $0.index < $1.index }

        for result in results {
            if let error = result.error {
                print("Upload preparation error: \(error)")
                continue
            }

            if let photoVideoDate = result.photoVideoDate,
               let imageVariants = result.imageVariants {
                viewModel.photoDatePairs.append(photoVideoDate)
                viewModel.preparedImageVariants.append(imageVariants)

                // Store video variant if present
                if let videoVariant = result.videoVariant {
                    viewModel.preparedVideoVariants.append(videoVariant)
                }
            }
        }
    }
}

private static func processLivePhoto(
    index: Int,
    stillImage: UIImage,
    liveData: LivePhotoComponentData,
    date: Date
) -> ProcessResult {
    // Prepare still image variants (3 qualities)
    guard let (photoData, variants) = prepareUIImage(stillImage) else {
        return (index, nil, nil, nil, LivePhotoError.failedToExtractStillImage)
    }

    // Prepare video component
    guard let videoVariant = VideoUploadHelper.prepareVideoForUpload(liveData.videoData) else {
        return (index, nil, nil, nil, LivePhotoError.failedToExtractVideo)
    }

    let videoDataNoPath = VideoUploadHelper.createVideoDataNoPath(from: videoVariant)

    let photoVideoDate = Components.Schemas.PhotoVideoDate(
        photo: photoData,
        video: videoDataNoPath,
        mediaType: .LIVE,
        dateCreated: convertFromDate(date)
    )

    return (
        index,
        photoVideoDate,
        (high: variants.high, med: variants.medium, low: variants.low),
        videoVariant,
        nil
    )
}

private static func processRegularPhoto(
    index: Int,
    image: UIImage,
    date: Date
) -> ProcessResult {
    guard let (photoData, variants) = prepareUIImage(image) else {
        return (index, nil, nil, nil, NSError(domain: "PhotoProcessing", code: -1))
    }

    let photoVideoDate = Components.Schemas.PhotoVideoDate(
        photo: photoData,
        video: nil,
        mediaType: .PHOTO,
        dateCreated: convertFromDate(date)
    )

    return (
        index,
        photoVideoDate,
        (high: variants.high, med: variants.medium, low: variants.low),
        nil,
        nil
    )
}
```

### 3.3 Update CreateViewModel

#### Add Video Variant Storage
**Location**: `Frontend/iOS/Clique/Clique/Core/Create/ViewModel/CreateViewModel.swift`

```swift
@Observable final class CreateViewModel {
    // ... existing properties ...

    /// Prepared video variants for Live Photos
    var preparedVideoVariants: [PreparedVideoVariant] = []

    // ... rest of class ...
}
```

### 3.4 Update Upload Service

#### Update `TabViewModel.swift` - Upload Function
**Location**: `Frontend/iOS/Clique/Clique/Utils/Coordinators/TabViewModel.swift`

**Update `uploadToCollection` to handle video uploads**:

```swift
func uploadToCollection(
    makingNew: Bool,
    photoDatePairs: [Components.Schemas.PhotoVideoDate],
    preparedImages: [(high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)],
    preparedVideos: [PreparedVideoVariant],  // NEW
    collection: ClCollection,
    _ collectionStore: CollectionStore,
    _ collectionImageStore: CollectionImageStore
) async throws {
    var collectionId: String

    if makingNew {
        let createdCollection = try await CollectionService.createCollection(.init(body: .json(.init(
            name: collection.name,
            description: collection.description,
            cliqueId: collection.cliqueId,
            privacySetting: mapFromVisibility(collection.visibility)
        ))))

        collectionId = createdCollection.collection!.collectionData!.collectionDataId!
    } else {
        collectionId = collection.id
    }

    let collectionWithPutLinks = try await CollectionService.uploadPhotosToCollection(
        .init(body: .json(.init(collectionId: collectionId, photos: photoDatePairs)))
    )

    let urlItems = collectionWithPutLinks.collection!.collectionItems!

    // Extract photo URLs
    let photoUrls: [(high: String?, med: String?, low: String?)] = urlItems.compactMap {
        guard let urls = $0.urls else { return nil }
        return (urls.url, urls.medQualityUrl, urls.lowQualityUrl)
    }

    // Extract video URLs for Live Photos
    let videoUrls: [String?] = urlItems.map { $0.videoUrls?.url }

    print("🚀 Preparing Upload")
    print("📸 Total Images: \(preparedImages.count)")
    print("🎥 Total Videos: \(preparedVideos.count)")
    print("🔗 Total URL Sets: \(photoUrls.count)")

    guard preparedImages.count == photoUrls.count else {
        print("❌ Error: Mismatch between images and URL sets")
        return
    }

    var failedUploadIndices: [Int] = []

    // Upload photos (all 3 qualities per photo)
    await PhotoHelper.uploadImages(
        preparedImages: preparedImages,
        urls: photoUrls,
        onProgress: { completed, total in
            self.successfulImages = completed
            self.totalImages = total
            print("✅ Upload \(completed)/\(total) complete")
        },
        failedUpload: { index, quality in
            print("❌ Failed upload at index \(index) for quality \(quality.rawValue)")
            if !failedUploadIndices.contains(index) {
                failedUploadIndices.append(index)
            }
        },
        onCompletion: { success in
            if success {
                Task {
                    // Now upload videos for Live Photos
                    await self.uploadVideos(
                        preparedVideos: preparedVideos,
                        videoUrls: videoUrls,
                        urlItems: urlItems,
                        collectionId: collectionId,
                        failedUploadIndices: failedUploadIndices
                    )
                }
            } else {
                // Handle photo upload failure
                self.handleUploadFailure(
                    preparedImages: preparedImages,
                    preparedVideos: preparedVideos,
                    urlItems: urlItems,
                    collectionId: collectionId,
                    failedIndices: failedUploadIndices
                )
            }
        }
    )

    self.collectionId = collectionId
}

// New function to upload videos
private func uploadVideos(
    preparedVideos: [PreparedVideoVariant],
    videoUrls: [String?],
    urlItems: [Components.Schemas.UrlCollectionItem],
    collectionId: String,
    failedUploadIndices: [Int]
) async {
    guard !preparedVideos.isEmpty else {
        // No videos to upload, mark photos as uploaded
        await markAsUploaded(urlItems: urlItems, collectionId: collectionId, failedIndices: failedUploadIndices)
        return
    }

    var videoFailedIndices: [Int] = []

    await VideoUploadHelper.uploadVideos(
        preparedVideos: preparedVideos,
        urls: videoUrls,
        onProgress: { completed, total in
            print("🎥 Video Upload \(completed)/\(total) complete")
        },
        failedUpload: { index in
            print("❌ Failed video upload at index \(index)")
            if !videoFailedIndices.contains(index) {
                videoFailedIndices.append(index)
            }
        },
        onCompletion: { success in
            Task {
                // Combine failed indices from photos and videos
                let allFailedIndices = Set(failedUploadIndices).union(Set(videoFailedIndices))
                await self.markAsUploaded(
                    urlItems: urlItems,
                    collectionId: collectionId,
                    failedIndices: Array(allFailedIndices)
                )
            }
        }
    )
}

private func markAsUploaded(
    urlItems: [Components.Schemas.UrlCollectionItem],
    collectionId: String,
    failedIndices: [Int]
) async {
    let successfulCollectionItemIds = urlItems
        .enumerated()
        .filter { !failedIndices.contains($0.offset) }
        .compactMap { $0.element.collectionItem?.collectionItemId }

    if !successfulCollectionItemIds.isEmpty {
        do {
            try await CollectionService.markCollectionImagesAsUploaded(
                .init(body: .json(.init(collectionItemIds: successfulCollectionItemIds, collectionId: collectionId)))
            )
            print("✅ All media uploaded!")
            self.reset()
        } catch {
            print("❌ Failed to mark as uploaded: \(error)")
        }
    }
}
```

### 3.5 Add Video Upload Helper

#### Update `VideoUploadHelper.swift` - Add Upload Function
**Location**: `Frontend/iOS/Clique/Clique/Helpers/Photos/VideoUploadHelper.swift`

```swift
extension VideoUploadHelper {
    /// Upload videos to S3 using presigned URLs
    static func uploadVideos(
        preparedVideos: [PreparedVideoVariant],
        urls: [String?],
        onProgress: @escaping (Int, Int) -> Void,
        failedUpload: @escaping (Int) -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) async {
        var completedUploads = 0
        let totalUploads = preparedVideos.count
        var hasFailures = false

        await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, video) in preparedVideos.enumerated() {
                guard index < urls.count, let urlString = urls[index], let url = URL(string: urlString) else {
                    failedUpload(index)
                    hasFailures = true
                    continue
                }

                group.addTask {
                    do {
                        try await uploadVideoToS3(video.data, to: url, contentType: video.params.contentType ?? "video/quicktime")
                        return (index, true)
                    } catch {
                        print("❌ Video upload failed at index \(index): \(error)")
                        return (index, false)
                    }
                }
            }

            for await (index, success) in group {
                if success {
                    completedUploads += 1
                    onProgress(completedUploads, totalUploads)
                } else {
                    failedUpload(index)
                    hasFailures = true
                }
            }
        }

        onCompletion(!hasFailures)
    }

    private static func uploadVideoToS3(_ data: Data, to url: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = data
        request.timeoutInterval = 120  // 2 minutes for large videos

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoUploadError.uploadFailed
        }
    }
}

enum VideoUploadError: Error {
    case uploadFailed
    case invalidURL
}
```

---

## Phase 4: Display & Playback Support

### 4.1 Create Live Photo View Component

**Priority**: High
**Estimated Effort**: 4-5 hours

#### Create `LivePhotoView.swift`
**Location**: `Frontend/iOS/Clique/Clique/Components/Media/LivePhotoView.swift`

```swift
import SwiftUI
import AVKit
import Kingfisher

/// View component for displaying Live Photos with playback support
struct LivePhotoView: View {
    let stillImageUrls: MediaUrls
    let videoUrls: MediaUrls
    let quality: ImageQuality
    let autoPlay: Bool

    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var queuePlayer: AVQueuePlayer?

    init(
        stillImageUrls: MediaUrls,
        videoUrls: MediaUrls,
        quality: ImageQuality = .medium,
        autoPlay: Bool = false
    ) {
        self.stillImageUrls = stillImageUrls
        self.videoUrls = videoUrls
        self.quality = quality
        self.autoPlay = autoPlay
    }

    var body: some View {
        ZStack {
            // Still image layer (always visible)
            GenericAsyncImage(
                urls: stillImageUrls,
                quality: quality,
                performanceMode: false
            ) { image in
                image
                    .contentConfigure { img in
                        img
                            .resizable()
                            .scaledToFit()
                    }
            } placeholder: {
                Rectangle()
                    .fill(.gray.opacity(0.2))
            }
            .opacity(isPlaying ? 0 : 1)

            // Video player layer
            if isPlaying, let player = player {
                VideoPlayer(player: player)
                    .disabled(true)  // Disable built-in controls
                    .transition(.opacity)
            }

            // Live Photo badge
            LivePhotoBadge()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            togglePlayback()
        }
        .onAppear {
            if autoPlay {
                playLivePhoto()
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            playLivePhoto()
        }
    }

    private func playLivePhoto() {
        guard let videoURL = videoUrls.url(for: .high) else { return }

        let playerItem = AVPlayerItem(url: videoURL)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

        self.queuePlayer = queuePlayer
        self.player = queuePlayer
        self.playerLooper = looper

        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = true
        }

        queuePlayer.play()

        // Auto-stop after 3 seconds (typical Live Photo duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            stopPlayback()
        }
    }

    private func stopPlayback() {
        player?.pause()
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = false
        }

        // Clean up
        playerLooper = nil
        queuePlayer = nil
        player = nil
    }
}

/// Live Photo indicator badge
struct LivePhotoBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "livephoto")
                .font(.caption2)
            Text("LIVE")
                .font(.caption2.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    LivePhotoView(
        stillImageUrls: MediaUrls(url: "https://example.com/photo.jpg"),
        videoUrls: MediaUrls(url: "https://example.com/video.mov")
    )
}
```

### 4.2 Create Standalone Video Player Component

#### Create `VideoPlayerView.swift`
**Location**: `Frontend/iOS/Clique/Clique/Components/Media/VideoPlayerView.swift`

```swift
import SwiftUI
import AVKit

/// Full-featured video player for standalone videos
struct VideoPlayerView: View {
    let videoUrls: MediaUrls
    let thumbnailUrls: MediaUrls?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true

    var body: some View {
        ZStack {
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        cleanup()
                    }
            } else {
                // Thumbnail while loading
                if let thumbnailUrls = thumbnailUrls {
                    GenericAsyncImage(
                        urls: thumbnailUrls,
                        quality: .medium
                    ) { image in
                        image
                            .contentConfigure { img in
                                img
                                    .resizable()
                                    .scaledToFit()
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                    }
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                }
            }

            // Video badge
            VideoBadge()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        }
    }

    private func setupPlayer() {
        guard let videoURL = videoUrls.url(for: .high) else { return }

        let player = AVPlayer(url: videoURL)
        self.player = player

        // Add observer for when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            isPlaying = false
        }
    }

    private func cleanup() {
        player?.pause()
        player = nil
    }
}

struct VideoBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "video.fill")
                .font(.caption2)
            Text("VIDEO")
                .font(.caption2.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

### 4.3 Update Collection Detail View

#### Update `CollectionDetailImageAsyncView.swift`
**Location**: `Frontend/iOS/Clique/Clique/Components/Kingfisher/Images/Collection/CollectionDetailImageAsyncView.swift`

```swift
import SwiftUI
import Kingfisher

struct CollectionDetailImageAsyncView: View {
    let collectionImage: CollectionImage
    let quality: ImageQuality

    var body: some View {
        Group {
            switch collectionImage.mediaType {
            case .PHOTO:
                // Standard photo display
                photoView

            case .LIVE:
                // Live Photo with playback
                if let stillUrls = collectionImage.imageUrl,
                   let videoUrls = collectionImage.videoUrls {
                    LivePhotoView(
                        stillImageUrls: stillUrls,
                        videoUrls: videoUrls,
                        quality: quality,
                        autoPlay: false
                    )
                    .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                    .clipped()
                } else {
                    photoView  // Fallback
                }

            case .VIDEO:
                // Standalone video
                if let videoUrls = collectionImage.videoUrls {
                    VideoPlayerView(
                        videoUrls: videoUrls,
                        thumbnailUrls: collectionImage.imageUrl
                    )
                    .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                    .clipped()
                } else {
                    photoView  // Fallback
                }
            }
        }
    }

    private var photoView: some View {
        GenericAsyncImage(urls: collectionImage.imageUrl, quality: quality) { image in
            image
                .contentConfigure { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                        .clipped()
                }
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
        }
    }
}
```

### 4.4 Update Grid Views with Media Type Badges

#### Update `GridCollectionPreviewImage`
**Location**: `Frontend/iOS/Clique/Clique/Components/Kingfisher/GridAsyncImage.swift`

```swift
/// Convenience wrapper for collection preview images in grids with media type support
struct GridCollectionPreviewImage: View {
    let collectionImage: CollectionImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Image thumbnail
            GenericAsyncImage(
                urls: collectionImage.imageUrl,
                quality: .low,
                shouldFixSize: false,
                performanceMode: true
            ) { image in
                image
                    .contentConfigure { img in
                        img.collectionPreviewImageModifiers()
                    }
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(Constants.collectionPreviewRatio, contentMode: .fill)
            }

            // Media type badge
            if collectionImage.mediaType != .PHOTO {
                MediaTypeBadge(mediaType: collectionImage.mediaType)
                    .padding(4)
            }
        }
    }
}

/// Small badge indicating media type in grid views
struct MediaTypeBadge: View {
    let mediaType: MediaType

    var body: some View {
        Image(systemName: iconName)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(3)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
    }

    private var iconName: String {
        switch mediaType {
        case .PHOTO: return "photo"
        case .LIVE: return "livephoto"
        case .VIDEO: return "video.fill"
        }
    }
}
```

---

## Phase 5: Store Updates & URL Management

### 5.1 Update CollectionImageStore

**Priority**: Medium
**Estimated Effort**: 2-3 hours

#### Update `CollectionImageStore.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Stores/CollectionImageStore.swift`

**Add video URL management**:

```swift
@Observable final class CollectionImageStore {
    // ... existing properties ...

    /// Update both photo and video URLs for a collection item
    func updateUrls(for id: String, photoUrls: MediaUrls?, videoUrls: MediaUrls?) {
        guard let index = collectionImages.firstIndex(where: { $0.id == id }) else { return }

        var image = collectionImages[index]
        var hasChanges = false

        // Update photo URLs if changed
        if let photoUrls = photoUrls, image.imageUrl != photoUrls {
            image.imageUrl = photoUrls
            hasChanges = true
        }

        // Update video URLs if changed
        if let videoUrls = videoUrls, image.videoUrls != videoUrls {
            image.videoUrls = videoUrls
            hasChanges = true
        }

        if hasChanges {
            collectionImages[index] = image
        }
    }

    /// Smart update - only refresh if URLs are expired or missing
    func smartUpdateUrls(for id: String, photoUrls: MediaUrls?, videoUrls: MediaUrls?) {
        guard let existing = collectionImages.first(where: { $0.id == id }) else { return }

        let shouldUpdatePhoto = photoUrls != nil && (existing.imageUrl == nil || urlsAreExpired(existing.imageUrl))
        let shouldUpdateVideo = videoUrls != nil && (existing.videoUrls == nil || urlsAreExpired(existing.videoUrls))

        if shouldUpdatePhoto || shouldUpdateVideo {
            updateUrls(for: id, photoUrls: shouldUpdatePhoto ? photoUrls : nil, videoUrls: shouldUpdateVideo ? videoUrls : nil)
        }
    }

    private func urlsAreExpired(_ urls: MediaUrls?) -> Bool {
        // Check if URLs contain expiration timestamp
        // S3 presigned URLs typically expire after 1 hour
        guard let urls = urls,
              let urlString = urls.url,
              let url = URL(string: urlString) else {
            return true
        }

        // Parse expiration from query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let expiryParam = components.queryItems?.first(where: { $0.name == "X-Amz-Expires" }),
           let expiryValue = expiryParam.value,
           let expirySeconds = TimeInterval(expiryValue) {

            // Assume URL was generated recently, expires in expirySeconds
            // Refresh if less than 10 minutes remaining
            return expirySeconds < 600
        }

        // If we can't determine expiration, assume it needs refresh
        return true
    }
}
```

### 5.2 Update CollectionStore

#### Update `CollectionStore.swift`
**Location**: `Frontend/iOS/Clique/Clique/Model/Stores/CollectionStore.swift`

**Update to handle MediaUrls**:

```swift
@Observable final class CollectionStore {
    // ... existing properties ...

    /// Smart update cover photo with expiration checking
    func smartUpdateCoverPhoto(for collectionId: String, coverPhoto: MediaUrls?) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }

        var collection = collections[index]

        // Only update if cover photo is new or expired
        if coverPhoto != nil && (collection.coverPhoto == nil || urlsAreExpired(collection.coverPhoto)) {
            collection.coverPhoto = coverPhoto
            collections[index] = collection
        }
    }

    private func urlsAreExpired(_ urls: MediaUrls?) -> Bool {
        // Same logic as CollectionImageStore
        guard let urls = urls, let urlString = urls.url, let url = URL(string: urlString) else {
            return true
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let expiryParam = components.queryItems?.first(where: { $0.name == "X-Amz-Expires" }),
           let expiryValue = expiryParam.value,
           let expirySeconds = TimeInterval(expiryValue) {
            return expirySeconds < 600
        }

        return true
    }
}
```

---

## Phase 6: Testing & Validation

### 6.1 Create Test Plan

**Priority**: High
**Estimated Effort**: 1 day

#### Test Scenarios

**Upload Tests**:
1. ✅ Upload regular photos (3 variants)
2. ✅ Upload Live Photos (3 photo variants + 1 video)
3. ✅ Upload mix of photos and Live Photos
4. ✅ Handle upload failures gracefully
5. ✅ Verify all URLs received from backend
6. ✅ Verify S3 upload success for all variants

**Display Tests**:
1. ✅ Display regular photos with progressive loading
2. ✅ Display Live Photos with badge
3. ✅ Tap to play Live Photo video
4. ✅ Display videos with controls
5. ✅ Grid view shows correct media type badges
6. ✅ Feed view renders all media types correctly

**Performance Tests**:
1. ✅ Upload 50 photos without memory issues
2. ✅ Upload 10 Live Photos (40 total files)
3. ✅ Scroll collection with 100+ Live Photos smoothly
4. ✅ Memory usage stays under 300MB during upload
5. ✅ Image cache doesn't exceed configured limits

**Edge Cases**:
1. ✅ Handle corrupted Live Photo (missing video component)
2. ✅ Handle network failure mid-upload
3. ✅ Handle expired S3 URLs
4. ✅ Handle missing video URLs for Live Photos
5. ✅ Handle backward compatibility with old data

### 6.2 Create Mock Data

#### Update Mock Data
**Location**: `Frontend/iOS/Clique/Clique/Model/ClCollection.swift`

```swift
extension CollectionImage {
    static var MOCK_LIVE_PHOTO: CollectionImage {
        CollectionImage(
            id: UUID().uuidString,
            imageUrl: MediaUrls(
                url: "https://example.com/photo-high.jpg",
                medQualityUrl: "https://example.com/photo-med.jpg",
                lowQualityUrl: "https://example.com/photo-low.jpg"
            ),
            videoUrls: MediaUrls(
                url: "https://example.com/video.mov"
            ),
            videoId: UUID().uuidString,
            mediaType: .LIVE,
            date: Date()
        )
    }

    static var MOCK_VIDEO: CollectionImage {
        CollectionImage(
            id: UUID().uuidString,
            videoUrls: MediaUrls(
                url: "https://example.com/video.mp4"
            ),
            videoId: UUID().uuidString,
            mediaType: .VIDEO,
            date: Date()
        )
    }
}
```

---

## Phase 7: UI/UX Enhancements

### 7.1 Upload Progress Indicators

**Priority**: Medium
**Estimated Effort**: 2-3 hours

#### Update `UploadProgressView.swift`
**Location**: `Frontend/iOS/Clique/Clique/Core/Create/View/UploadProgressView.swift`

**Add separate progress tracking for photos and videos**:

```swift
struct UploadProgressView: View {
    @Environment(TabViewModel.self) var tabViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Overall progress
            Text("Uploading Media")
                .font(.headline)

            // Photo upload progress
            if tabViewModel.totalImages > 0 {
                HStack {
                    Image(systemName: "photo.fill")
                    ProgressView(value: Double(tabViewModel.successfulImages), total: Double(tabViewModel.totalImages))
                    Text("\(tabViewModel.successfulImages)/\(tabViewModel.totalImages)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Video upload progress (if any)
            if tabViewModel.totalVideos > 0 {
                HStack {
                    Image(systemName: "video.fill")
                    ProgressView(value: Double(tabViewModel.successfulVideos), total: Double(tabViewModel.totalVideos))
                    Text("\(tabViewModel.successfulVideos)/\(tabViewModel.totalVideos)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}
```

### 7.2 Media Type Filter

**Priority**: Low
**Estimated Effort**: 2 hours

#### Create `MediaTypeFilter.swift`
**Location**: `Frontend/iOS/Clique/Clique/Components/Filters/MediaTypeFilter.swift`

```swift
import SwiftUI

struct MediaTypeFilter: View {
    @Binding var selectedTypes: Set<MediaType>
    let availableTypes: Set<MediaType>

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(availableTypes).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                MediaTypeChip(
                    mediaType: type,
                    isSelected: selectedTypes.contains(type)
                ) {
                    if selectedTypes.contains(type) {
                        selectedTypes.remove(type)
                    } else {
                        selectedTypes.insert(type)
                    }
                }
            }
        }
    }
}

struct MediaTypeChip: View {
    let mediaType: MediaType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mediaType.iconName)
                    .font(.caption)
                Text(mediaType.displayName)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}
```

---

## Phase 8: Documentation & Cleanup

### 8.1 Update CLAUDE.md

**Priority**: Medium
**Estimated Effort**: 1 hour

**Add sections for**:
- Media type system (PHOTO, LIVE, VIDEO)
- Live Photo extraction and upload flow
- Video upload process
- Display components (LivePhotoView, VideoPlayerView)
- MediaUrls structure and quality variants

### 8.2 Add DocC Documentation

**Priority**: Low
**Estimated Effort**: 2-3 hours

**Document**:
- `LivePhotoHelper.swift` - Live Photo extraction APIs
- `VideoUploadHelper.swift` - Video upload utilities
- `LivePhotoView.swift` - Live Photo display component
- `MediaType` enum - Media type system
- `MediaUrls` struct - URL structure

### 8.3 Cleanup & Deprecation

**Remove deprecated code**:
- Old `PhotoUrls` references (after full migration to `MediaUrls`)
- Old `PhotoDatePair` usage (replaced by `PhotoVideoDate`)
- Any single-URL upload logic

---

## Implementation Timeline

### Week 1: Foundation (Phase 1)
- Day 1-2: Create models, enums, update DTOs
- Day 3-4: Global find & replace, update all references
- Day 5: Testing and validation

### Week 2: Upload Support (Phases 2-3)
- Day 1-2: Live Photo detection and extraction
- Day 3-4: Update upload flow for Live Photos and videos
- Day 5: Testing upload functionality

### Week 3: Display & Playback (Phases 4-5)
- Day 1-2: Create Live Photo and video player components
- Day 3-4: Update collection views and grid views
- Day 5: Store updates and URL management

### Week 4: Polish & Testing (Phases 6-8)
- Day 1-2: Comprehensive testing
- Day 3: UI/UX enhancements
- Day 4: Documentation
- Day 5: Final validation and deployment

---

## Risk Assessment

### High Risk Areas

1. **Live Photo Extraction**
   - **Risk**: Inconsistent behavior across iOS versions
   - **Mitigation**: Comprehensive testing on iOS 17 and iOS 18

2. **Video Upload Performance**
   - **Risk**: Large video files may cause memory issues
   - **Mitigation**: Implement chunked uploads if needed, monitor memory usage

3. **Backward Compatibility**
   - **Risk**: Existing users' data may not have video URLs
   - **Mitigation**: Graceful fallbacks, check for nil video URLs

4. **S3 URL Expiration**
   - **Risk**: URLs expire before playback
   - **Mitigation**: Implement smart refresh logic, check expiration timestamps

### Medium Risk Areas

1. **Kingfisher Cache with Videos**
   - **Risk**: Video caching may consume excessive disk space
   - **Mitigation**: Separate cache configuration for videos

2. **Network Resilience**
   - **Risk**: Upload failures with mixed photo/video uploads
   - **Mitigation**: Robust retry logic, separate failure tracking

3. **UI Performance**
   - **Risk**: Scrolling lag with many Live Photos
   - **Mitigation**: Use performance mode, implement proper cleanup

---

## Success Criteria

### Must Have (MVP)
✅ Upload regular photos with 3 quality variants
✅ Upload Live Photos (still + video)
✅ Display Live Photos with playback
✅ Display media type badges
✅ Backward compatibility with existing data
✅ No performance degradation in feed/grids

### Should Have
✅ Standalone video upload support
✅ Progressive video loading
✅ Upload retry for failed videos
✅ Media type filtering

### Nice to Have
⭕ Video trimming before upload
⭕ Thumbnail generation for videos
⭕ Live Photo editing (crop, rotate)
⭕ Media type analytics

---

## Migration Strategy

### Phased Rollout

**Phase A: Backend Deployment**
- Deploy backend changes to staging
- Verify API endpoints work correctly
- Test with Postman/API clients

**Phase B: iOS Beta Testing**
- Deploy to TestFlight beta
- Monitor crash reports and analytics
- Gather user feedback

**Phase C: Gradual Rollout**
- Release to 10% of users
- Monitor performance metrics
- Increase to 50% if stable
- Full rollout after 1 week

### Rollback Plan

If critical issues arise:
1. Revert to previous app version via App Store
2. Backend can handle old schema (PhotoUrls still works)
3. Database migrations are additive only (safe to rollback)

---

## Post-Launch Monitoring

### Key Metrics to Track

1. **Upload Success Rate**
   - Photo uploads: Target >98%
   - Video uploads: Target >95%

2. **Performance Metrics**
   - App memory usage: Keep under 350MB during uploads
   - Feed scroll FPS: Maintain 60fps with Live Photos
   - Upload time: Monitor average time per media type

3. **User Engagement**
   - Live Photo usage rate
   - Video playback rate
   - Media type distribution in new uploads

4. **Error Rates**
   - Live Photo extraction failures
   - Video upload timeouts
   - S3 URL expiration issues

---

## 🚀 Comprehensive Plan for Remaining Work

### Phase 0: Backend Upload Status Integration (IMMEDIATE PRIORITY)

**Objective**: Stop marking uploads manually and display backend-tracked upload status in UI

**Steps**:

1. **Build Xcode Project to Regenerate OpenAPI Types**
   - Open Xcode project
   - Build project (⌘B) to trigger Swift OpenAPI Generator
   - Verify `Components.Schemas.UploadStatus` enum is generated
   - Verify `Components.Schemas.CollectionItem` has `uploadStatus` field

2. **Add UploadStatus to Domain Model**
   ```swift
   // In ClCollection.swift
   enum UploadStatus: String, Codable, Hashable, Sendable {
       case PENDING
       case FAILED
       case COMPLETED
   }

   struct CollectionImage: Identifiable, Hashable, Codable {
       // ... existing fields ...
       var uploadStatus: UploadStatus? = nil
   }
   ```

3. **Update DTO Mapping**
   ```swift
   // In CollectionDTO.swift
   func mapToUploadStatus(_ status: Components.Schemas.UploadStatus) -> UploadStatus {
       switch status {
       case .PENDING: return .PENDING
       case .FAILED: return .FAILED
       case .COMPLETED: return .COMPLETED
       }
   }

   func mapToCollectionImage(_ data: Components.Schemas.UrlCollectionItem) -> CollectionImage {
       return CollectionImage(
           // ... existing fields ...
           uploadStatus: data.collectionItem?.uploadStatus != nil ? mapToUploadStatus(data.collectionItem!.uploadStatus!) : nil
       )
   }
   ```

4. **Remove Upload Marking Calls**
   ```swift
   // In TabViewModel.swift - DELETE these sections:

   // Line ~114-116 in uploadToCollection:
   try await CollectionService.markCollectionImagesAsUploaded(...)  // REMOVE

   // Line ~181-183 in retryUploadImages:
   try await CollectionService.markCollectionImagesAsUploaded(...)  // REMOVE
   ```

5. **Create Upload Status Overlay Component**
   ```swift
   // New file: Components/Advanced/UploadStatusOverlay.swift
   struct UploadStatusOverlay: View {
       let status: UploadStatus?
       let onRetry: (() -> Void)?

       var body: some View {
           Group {
               switch status {
               case .PENDING:
                   pendingOverlay
               case .FAILED:
                   failedOverlay
               case .COMPLETED, .none:
                   EmptyView()
               }
           }
       }

       private var pendingOverlay: some View {
           ZStack {
               Color.black.opacity(0.3)
               ProgressView()
                   .progressViewStyle(.circular)
                   .tint(.white)
           }
       }

       private var failedOverlay: some View {
           ZStack {
               Color.red.opacity(0.3)
               VStack(spacing: 8) {
                   Image(systemName: "exclamationmark.triangle.fill")
                       .foregroundColor(.white)
                   if let onRetry = onRetry {
                       Button("Retry") {
                           onRetry()
                       }
                       .buttonStyle(.bordered)
                       .tint(.white)
                   }
               }
           }
       }
   }
   ```

6. **Add View Extension**
   ```swift
   // In ViewExtensions.swift
   extension View {
       func overlayUploadStatus(_ status: UploadStatus?, onRetry: (() -> Void)? = nil) -> some View {
           self.overlay {
               UploadStatusOverlay(status: status, onRetry: onRetry)
           }
       }
   }
   ```

7. **Apply to Collection Grid**
   ```swift
   // In CollectionMainView.swift, update ImageCell (line ~494):
   @ViewBuilder private func ImageCell(_ image: CollectionImage) -> some View {
       CollectionPreviewAsyncImage(urls: image.imageUrl, quality: .medium)
           .overlayCollectionPreviewStats(likes: image.numLikes, comments: image.numComments, hasLiked: image.hasLiked)
           .overlayUploadStatus(image.uploadStatus)  // ADD THIS
           .id(image.id)
           .heroSource(urls: image.imageUrl) {
               tabCoordinator.showTabBar = false
               clCoordinator.selectedImageId = image.id
           }
   }
   ```

**Testing Checklist**:
- [ ] Build succeeds after regeneration
- [ ] Upload new images → see PENDING status
- [ ] Backend processes → status changes to COMPLETED
- [ ] Failed uploads show FAILED overlay
- [ ] No calls to markCollectionImagesAsUploaded in logs
- [ ] Grids display all status states correctly

---

### Phase 4: Display & Playback Support (NEXT PRIORITY)

**Objective**: Enable Live Photo playback and video viewing in the app

#### 4.1 Create Live Photo View Component

**File**: `Components/Media/LivePhotoView.swift`

**Key Features**:
- Still image layer (always visible)
- Video player layer (shows on tap)
- Live Photo badge (top-left corner)
- Tap to play/stop
- Auto-stop after 3 seconds
- Proper cleanup on disappear

**Implementation Strategy**:
1. Use `AVQueuePlayer` with `AVPlayerLooper` for seamless looping
2. Animate transition between still and video (opacity)
3. Load video from `MediaUrls` (use high quality URL)
4. Handle missing video URLs gracefully

#### 4.2 Create Video Player Component

**File**: `Components/Media/VideoPlayerView.swift`

**Key Features**:
- Full video controls via VideoPlayer
- Thumbnail preview before playback
- Video badge indicator
- Auto-seek to beginning on end
- Memory cleanup

#### 4.3 Update Collection Detail View

**File**: `Components/Kingfisher/Images/Collection/CollectionDetailImageAsyncView.swift`

**Changes**:
```swift
var body: some View {
    Group {
        switch collectionImage.mediaType {
        case .PHOTO:
            photoView
        case .LIVE:
            if let stillUrls = collectionImage.imageUrl,
               let videoUrls = collectionImage.videoUrls {
                LivePhotoView(stillImageUrls: stillUrls, videoUrls: videoUrls, quality: quality)
            } else {
                photoView  // Fallback
            }
        case .VIDEO:
            if let videoUrls = collectionImage.videoUrls {
                VideoPlayerView(videoUrls: videoUrls, thumbnailUrls: collectionImage.imageUrl)
            } else {
                photoView  // Fallback
            }
        }
    }
}
```

#### 4.4 Add Media Type Badges to Grid

**File**: `Components/Kingfisher/GridAsyncImage.swift`

**Add**:
```swift
struct MediaTypeBadge: View {
    let mediaType: MediaType

    var body: some View {
        Image(systemName: iconName)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(3)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
    }

    private var iconName: String {
        switch mediaType {
        case .PHOTO: return "photo"
        case .LIVE: return "livephoto"
        case .VIDEO: return "video.fill"
        }
    }
}
```

**Update GridCollectionPreviewImage**:
```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // ... existing image ...

        if collectionImage.mediaType != .PHOTO {
            MediaTypeBadge(mediaType: collectionImage.mediaType)
                .padding(4)
        }
    }
}
```

**Files to Create**:
- `Components/Media/LivePhotoView.swift`
- `Components/Media/VideoPlayerView.swift`

**Files to Modify**:
- `Components/Kingfisher/Images/Collection/CollectionDetailImageAsyncView.swift`
- `Components/Kingfisher/GridAsyncImage.swift`

**Testing**:
- [ ] Live Photos display with badge
- [ ] Tap Live Photo to play video
- [ ] Video stops after 3 seconds
- [ ] Videos show controls
- [ ] Grid shows media type badges
- [ ] Detail view switches based on media type

---

### Phase 5: Store Updates & URL Management

**Objective**: Properly manage video URLs alongside photo URLs with expiration handling

#### 5.1 Update CollectionImageStore

**File**: `Model/Stores/CollectionImageStore.swift`

**Add Methods**:
```swift
/// Update both photo and video URLs for a collection item
func updateUrls(for id: String, photoUrls: MediaUrls?, videoUrls: MediaUrls?) {
    guard let index = images.firstIndex(where: { $0.id == id }) else { return }

    var image = images[index]
    var hasChanges = false

    if let photoUrls = photoUrls, image.imageUrl != photoUrls {
        image.imageUrl = photoUrls
        hasChanges = true
    }

    if let videoUrls = videoUrls, image.videoUrls != videoUrls {
        image.videoUrls = videoUrls
        hasChanges = true
    }

    if hasChanges {
        images[index] = image
    }
}

/// Smart update - only refresh if URLs are expired
func smartUpdateUrls(for id: String, photoUrls: MediaUrls?, videoUrls: MediaUrls?) {
    guard let existing = images.first(where: { $0.id == id }) else { return }

    let shouldUpdatePhoto = photoUrls != nil && (existing.imageUrl == nil || urlsAreExpired(existing.imageUrl))
    let shouldUpdateVideo = videoUrls != nil && (existing.videoUrls == nil || urlsAreExpired(existing.videoUrls))

    if shouldUpdatePhoto || shouldUpdateVideo {
        updateUrls(for: id, photoUrls: shouldUpdatePhoto ? photoUrls : nil, videoUrls: shouldUpdateVideo ? videoUrls : nil)
    }
}

private func urlsAreExpired(_ urls: MediaUrls?) -> Bool {
    guard let urls = urls, let urlString = urls.url, let url = URL(string: urlString) else {
        return true
    }

    // Check S3 expiration parameter
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let expiryParam = components.queryItems?.first(where: { $0.name == "X-Amz-Expires" }),
       let expiryValue = expiryParam.value,
       let expirySeconds = TimeInterval(expiryValue) {
        return expirySeconds < 600  // Refresh if <10 mins remaining
    }

    return true
}
```

#### 5.2 Update CollectionStore

**File**: `Model/Stores/CollectionStore.swift`

**Add Methods**:
```swift
func smartUpdateCoverPhoto(for collectionId: String, coverPhoto: MediaUrls?) {
    guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }

    var collection = collections[index]

    if coverPhoto != nil && (collection.coverPhoto == nil || urlsAreExpired(collection.coverPhoto)) {
        collection.coverPhoto = coverPhoto
        collections[index] = collection
    }
}

private func urlsAreExpired(_ urls: MediaUrls?) -> Bool {
    // Same logic as CollectionImageStore
}
```

**Files to Modify**:
- `Model/Stores/CollectionImageStore.swift`
- `Model/Stores/CollectionStore.swift`

**Testing**:
- [ ] Video URLs update correctly
- [ ] Expired URLs trigger refresh
- [ ] Valid URLs don't refresh unnecessarily
- [ ] Cover photos with videos work

---

### Phase 6: Testing & Validation

**Objective**: Comprehensive testing across all scenarios

#### Upload Tests
- [ ] Upload 10 regular photos (30 variants total)
- [ ] Upload 5 Live Photos (15 photo variants + 5 videos)
- [ ] Upload mix: 5 photos + 3 Live Photos
- [ ] Handle network failure mid-upload
- [ ] Retry failed uploads
- [ ] Verify S3 upload success for all variants

#### Display Tests
- [ ] Display regular photos with progressive loading
- [ ] Display Live Photos with badge
- [ ] Tap to play Live Photo video
- [ ] Video stops after duration
- [ ] Grid shows correct badges for all types
- [ ] Detail view renders all media types

#### Performance Tests
- [ ] Upload 50 photos without memory issues
- [ ] Upload 10 Live Photos (memory stays under 300MB)
- [ ] Scroll collection with 100+ items smoothly
- [ ] Video playback doesn't block UI
- [ ] Image cache respects limits

#### Edge Cases
- [ ] Handle Live Photo with missing video
- [ ] Handle expired S3 URLs
- [ ] Handle backward compatibility (old data without uploadStatus)
- [ ] Handle upload status transitions
- [ ] Handle corrupted video data

#### Mock Data
Update `ClCollection.swift`:
```swift
extension CollectionImage {
    static var MOCK_LIVE_PHOTO: CollectionImage {
        CollectionImage(
            id: UUID().uuidString,
            imageUrl: MediaUrls(url: "...", medQualityUrl: "...", lowQualityUrl: "..."),
            videoUrls: MediaUrls(url: "..."),
            videoId: UUID().uuidString,
            mediaType: .LIVE,
            date: Date(),
            uploadStatus: .COMPLETED
        )
    }

    static var MOCK_PENDING_PHOTO: CollectionImage {
        CollectionImage(
            id: UUID().uuidString,
            imageUrl: MediaUrls(url: "..."),
            mediaType: .PHOTO,
            date: Date(),
            uploadStatus: .PENDING
        )
    }

    static var MOCK_FAILED_PHOTO: CollectionImage {
        CollectionImage(
            id: UUID().uuidString,
            imageUrl: MediaUrls(url: "..."),
            mediaType: .PHOTO,
            date: Date(),
            uploadStatus: .FAILED
        )
    }
}
```

---

### Phase 7: UI/UX Enhancements

**Objective**: Polish the user experience

#### 7.1 Enhanced Upload Progress

**File**: `Core/Create/View/UploadProgressView.swift`

**Add**:
- Separate progress bars for photos and videos
- Estimated time remaining
- Upload speed indicator
- Cancel upload option

```swift
struct UploadProgressView: View {
    // ... existing properties ...

    var body: some View {
        VStack(spacing: 16) {
            Text("Uploading Media")
                .font(.headline)

            // Photo progress
            if totalImages > 0 {
                HStack {
                    Image(systemName: "photo.fill")
                    ProgressView(value: Double(successfulImages), total: Double(totalImages))
                    Text("\(successfulImages)/\(totalImages)")
                        .font(.caption)
                }
            }

            // Video progress (for Live Photos)
            if totalVideos > 0 {
                HStack {
                    Image(systemName: "video.fill")
                    ProgressView(value: Double(successfulVideos), total: Double(totalVideos))
                    Text("\(successfulVideos)/\(totalVideos)")
                        .font(.caption)
                }
            }
        }
    }
}
```

#### 7.2 Media Type Filter

**File**: `Components/Filters/MediaTypeFilter.swift` (NEW)

**Purpose**: Allow users to filter collections by media type

```swift
struct MediaTypeFilter: View {
    @Binding var selectedTypes: Set<MediaType>
    let availableTypes: Set<MediaType>

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(availableTypes).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                MediaTypeChip(
                    mediaType: type,
                    isSelected: selectedTypes.contains(type)
                ) {
                    if selectedTypes.contains(type) {
                        selectedTypes.remove(type)
                    } else {
                        selectedTypes.insert(type)
                    }
                }
            }
        }
    }
}

struct MediaTypeChip: View {
    let mediaType: MediaType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mediaType.iconName)
                Text(mediaType.displayName)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}
```

**Usage** in `CollectionMainView.swift`:
```swift
MediaTypeFilter(
    selectedTypes: $selectedMediaTypes,
    availableTypes: Set(collection.images.map { $0.mediaType })
)
.padding(.horizontal)
```

**Files to Create**:
- `Components/Filters/MediaTypeFilter.swift`

**Files to Modify**:
- `Core/Create/View/UploadProgressView.swift`
- `Core/Collection/View/CollectionMainView.swift` (add filter)

---

### Phase 8: Documentation & Cleanup

**Objective**: Document the implementation and clean up deprecated code

#### 8.1 Update CLAUDE.md

Add sections:
- **Media Type System**: Explain PHOTO, LIVE, VIDEO
- **Live Photo Flow**: Detection → Extraction → Upload → Display
- **Video Upload**: Streaming upload with memory optimization
- **Upload Status**: Backend-managed status system
- **Display Components**: LivePhotoView, VideoPlayerView usage
- **MediaUrls**: Quality variant structure

#### 8.2 DocC Documentation

Add comprehensive docs:
- `LivePhotoHelper.swift` - All public APIs
- `VideoUploadHelper.swift` - Upload utilities
- `LivePhotoView.swift` - Component usage
- `MediaType` enum - Type system
- `MediaUrls` struct - URL structure
- `UploadStatus` enum - Status values

#### 8.3 Code Cleanup

**Remove**:
- Any remaining `PhotoUrls` references (should be none)
- Old `PhotoDatePair` mentions (replaced by `PhotoVideoDate`)
- Deprecated upload marking logic
- Unused import statements
- Debug print statements

**Verify**:
- All compiler warnings resolved
- No forced unwraps (use guard/if let)
- Proper error handling throughout
- Consistent code style

---

## Appendix A: File Checklist

### Files Created ✅
- [x] `Frontend/iOS/Clique/Clique/Model/MediaType.swift`
- [x] `Frontend/iOS/Clique/Clique/Model/Helpers/MediaUrls.swift`
- [x] `Frontend/iOS/Clique/Clique/Helpers/Photos/LivePhotoHelper.swift`
- [x] `Frontend/iOS/Clique/Clique/Helpers/Photos/VideoUploadHelper.swift`

### Files to Create 🚧
- [ ] `Frontend/iOS/Clique/Clique/Components/Advanced/UploadStatusOverlay.swift` (Phase 0)
- [ ] `Frontend/iOS/Clique/Clique/Components/Media/LivePhotoView.swift` (Phase 4)
- [ ] `Frontend/iOS/Clique/Clique/Components/Media/VideoPlayerView.swift` (Phase 4)
- [ ] `Frontend/iOS/Clique/Clique/Components/Filters/MediaTypeFilter.swift` (Phase 7)

### Files Updated ✅
- [x] `Frontend/iOS/Clique/Clique/Model/ClCollection.swift` (Phase 1 - needs uploadStatus for Phase 0)
- [x] `Frontend/iOS/Clique/Clique/Model/User.swift` (Phase 1)
- [x] `Frontend/iOS/Clique/Clique/Model/Clique.swift` (Phase 1)
- [x] `Frontend/iOS/Clique/Clique/Model/Data/CollectionDTO.swift` (Phase 1 - needs uploadStatus mapping for Phase 0)
- [x] `Frontend/iOS/Clique/Clique/Model/Data/UserDTO.swift` (Phase 1)
- [x] `Frontend/iOS/Clique/Clique/Model/Data/CliqueDTO.swift` (Phase 1)
- [x] `Frontend/iOS/Clique/Clique/Model/Data/MediaUrlsDTO.swift` (Phase 1)
- [x] `Frontend/iOS/Clique/Clique/Core/Create/ViewModel/CreateViewModel.swift` (Phase 2 & 3)
- [x] `Frontend/iOS/Clique/Clique/Core/Create/Helpers/PhotoProcessingHelper.swift` (Phase 2 & 3)
- [x] `Frontend/iOS/Clique/Clique/Utils/Coordinators/TabViewModel.swift` (Phase 3 - needs upload marking removal for Phase 0)
- [x] `Frontend/iOS/Clique/Clique/Helpers/Photos/PhotoHelper.swift` (Phase 3 - streaming uploads)
- [x] 44 files updated from PhotoUrls → MediaUrls (Phase 1)

### Files to Update 🚧
- [ ] `Frontend/iOS/Clique/Clique/Helpers/Extensions/ViewExtensions.swift` (Phase 0)
- [ ] `Frontend/iOS/Clique/Clique/Core/Collection/View/CollectionMainView.swift` (Phase 0 & 4)
- [ ] `Frontend/iOS/Clique/Clique/Components/Kingfisher/Images/Collection/CollectionDetailImageAsyncView.swift` (Phase 4)
- [ ] `Frontend/iOS/Clique/Clique/Components/Kingfisher/GridAsyncImage.swift` (Phase 4)
- [ ] `Frontend/iOS/Clique/Clique/Model/Stores/CollectionImageStore.swift` (Phase 5)
- [ ] `Frontend/iOS/Clique/Clique/Model/Stores/CollectionStore.swift` (Phase 5)
- [ ] `Frontend/iOS/Clique/Clique/Core/Create/View/UploadProgressView.swift` (Phase 7)
- [ ] `Frontend/iOS/Clique/CLAUDE.md` (Phase 8)

### Files to Delete
- [ ] `Frontend/iOS/Clique/Clique/Model/Helpers/PhotoUrls.swift` (replaced by MediaUrls.swift)
- [ ] `Frontend/iOS/Clique/Clique/Model/Data/PhotoUrlsDTO.swift` (replaced by MediaUrlsDTO.swift)

---

## Appendix B: OpenAPI Schema Reference

### Key Schema Changes

**From (Old)**:
```yaml
PhotoUrls:
  url: string
  medQualityUrl: string
  lowQualityUrl: string

PhotoDatePair:
  photo: PhotoDataNoPath
  dateCreated: string
```

**To (New)**:
```yaml
MediaUrls:
  url: string
  medQualityUrl: string
  lowQualityUrl: string

PhotoVideoDate:
  photo: PhotoDataNoPath
  video: VideoDataNoPath
  mediaType: MediaType  # NEW
  dateCreated: string

MediaType:
  enum: [PHOTO, LIVE, VIDEO]  # NEW

UrlCollectionItem:
  urls: MediaUrls
  videoUrls: MediaUrls  # NEW
  collectionItem: CollectionItem
  isLiked: boolean

CollectionItem:
  collectionItemId: uuid
  photoId: uuid
  videoId: uuid  # NEW
  mediaType: MediaType  # NEW
  likes: integer
  commentCount: integer
  dateCreated: string
```

---

## Appendix C: Questions for Backend Team

1. ✅ **Video Quality Variants**: Does the backend generate medium/low quality versions of videos, or should iOS upload only the base video?
   - **Assumption**: Backend generates variants (iOS uploads only base video)

2. ✅ **Video Thumbnails**: For standalone VIDEO types, should iOS generate and upload a still frame thumbnail to populate the `urls` field?
   - **Assumption**: Yes, iOS should generate thumbnail

3. ✅ **Live Photo Video Duration**: Any specific requirements for Live Photo video duration or format?
   - **Assumption**: Standard iOS Live Photo format (3-4 seconds, H.264)

4. ✅ **Migration**: Will existing collection items be backfilled with quality variants?
   - **Assumption**: No, only new uploads will have variants

5. ✅ **S3 URL Expiration**: How long do S3 URLs remain valid? Current refresh strategy sufficient?
   - **Assumption**: 1 hour, refresh when <10 minutes remaining

---

## Conclusion

This implementation plan provides a comprehensive roadmap for adding Live Photo and video support to the Clique iOS app. The phased approach ensures systematic progress while maintaining code quality and backward compatibility.

**Key Success Factors**:
- Thorough testing at each phase
- Robust error handling for edge cases
- Performance monitoring throughout
- Clear communication with backend team
- Gradual rollout with monitoring

**Next Steps**:
1. Review plan with team
2. Get backend team confirmation on assumptions
3. Begin Phase 1 implementation
4. Set up TestFlight beta for early testing