# Video Playback Issue - Technical Investigation Report

**Date:** October 19, 2025
**Branch:** `rt/livephotos-videos`
**Platform:** iOS (Swift/SwiftUI)
**Backend:** Kotlin Spring Boot with ffmpeg processing

---

## Problem Statement

Videos uploaded from the iOS app (both standalone videos and Live Photo video components) fail to play in AVPlayer. The videos download successfully, pass all validation checks, but AVPlayer never transitions from status 0 (Unknown) to status 1 (ReadyToPlay).

### Symptoms
- ✅ Video downloads successfully from S3
- ✅ File exists on disk with `.mp4` extension
- ✅ AVAsset reports `isPlayable = true`
- ✅ Correct codec (H.264 avc1)
- ✅ Valid duration and track information
- ❌ AVPlayer status stuck at 0 forever
- ❌ 15-second timeout error: "Video loading timed out"

---

## Architecture Overview

### Current Upload Flow

1. **iOS Client** (`LivePhotoHelper.swift`)
   - Extracts video from Live Photo or standalone video asset
   - **Transcodes with `AVAssetExportSession`** to MP4
   - Uploads transcoded MP4 to S3 via presigned URL

2. **Backend** (Kotlin - `ProcessingServiceImpl.kt`)
   - Receives Kafka message on `"new-media-created"` topic
   - Downloads uploaded video from S3
   - **Processes with ffmpeg** to create multiple quality versions:
     - **Original** (as uploaded)
     - **720p medium**: `scale=-2:720, bitrate=1500k, AAC 128k`
     - **360p low**: `scale=-2:360, bitrate=800k, AAC 64k`
   - **Uses `-movflags +faststart`** for streaming optimization
   - Uploads processed versions back to S3

3. **iOS Playback** (`NetworkVideoPlayerView.swift`)
   - Downloads video from S3 using `VideoCache`
   - Caches locally with `.mp4` extension
   - Creates `AVPlayer` from cached file
   - **Fails** - Player never becomes ready

### Backend Video Processing Code

```kotlin
// ProcessingServiceImpl.kt lines 150-219
private fun processVideo(video: Video) {
    val inputFile = File.createTempFile("input-${video.id}", ".mp4")
    s3.getS3Client().getObject(/* download from S3 */, inputFile.toPath())

    val mediumFile = File.createTempFile("720p-${video.id}", ".mp4")
    val lowFile = File.createTempFile("360p-${video.id}", ".mp4")

    // 720p processing
    runFfmpegAsyncCoroutine(
        listOf(
            "ffmpeg", "-i", inputFile.absolutePath,
            "-vf", "scale=-2:720",
            "-b:v", "1500k",
            "-c:a", "aac", "-b:a", "128k",
            "-movflags", "+faststart",  // <-- Critical for streaming
            "-y", mediumFile.absolutePath,
        )
    )

    // Similar for 360p...
    // Upload processed files back to S3
}
```

---

## What We've Tried

### Attempt 1: AVAssetExportPresetPassthrough
**Goal:** Just change container from MOV to MP4 without re-encoding
**Result:** ❌ Failed
- Created `AppleProResHW` hardware encoding error
- Video technically valid but AVPlayer refuses to play
- File size: ~22MB for 6.8s video

**Error Log:**
```
ERROR AppleProResHW:  45 :  AppleProResHW_CheckPlatform (): IOServiceGetMatchingService failed
```

### Attempt 2: AVAssetExportPresetHighestQuality
**Goal:** Use highest quality preset for better compatibility
**Result:** ❌ Failed
- Same AppleProResHW error
- AVPlayer status still stuck at 0
- Video metadata looked correct but wouldn't play

### Attempt 3: AVAssetExportPreset3840x2160 (4K)
**Goal:** Explicitly set 4K quality preset
**Result:** ❌ Failed
- Same AppleProResHW error
- AVPlayer timeout after 15 seconds
- Video dimensions: 2160x3840 (4K)

### Attempt 4: AVAssetExportPreset1920x1080 (1080p) - CURRENT
**Goal:** Test if lower resolution works
**Result:** ❌ Failed
- Still get AppleProResHW error
- **Video still 4K resolution** (2160x3840) - preset didn't downsample!
- AVPlayer timeout persists

**Validation Output:**
```
📹 AVAsset validation results:
   ✅ Is playable: true
   ✅ Duration: 6.835 seconds
   ✅ Total tracks: 7
   🎬 Video tracks: 1
      Track 0:
         Codec: avc1
         Size: 2160.0x3840.0  // Still 4K despite 1080p preset!
   🔊 Audio tracks: 1
⏳ Waiting for video to become ready...
⏱️ Video loading timed out after 15.0s
```

---

## Root Cause Analysis

### The Core Problem: Client-Side Transcoding is Broken

`AVAssetExportSession` is creating MP4 files that are technically valid (pass AVAsset validation) but are fundamentally incompatible with AVPlayer playback. The issue manifests in multiple ways:

1. **Hardware Encoding Errors:** AppleProResHW failures suggest incompatible codec parameters
2. **Preset Failures:** Even "safe" presets like 1080p don't actually downsample or fix compatibility
3. **Metadata Issues:** The MP4 container structure may not have proper moov atom positioning
4. **Missing Optimization:** No streaming optimization flags (equivalent to `-movflags +faststart`)

### Why Backend Processing Should Work

The backend's ffmpeg command includes **critical optimizations** that client-side transcoding lacks:

```bash
ffmpeg -i input.mp4 \
  -vf "scale=-2:720" \
  -b:v "1500k" \
  -c:a "aac" -b:a "128k" \
  -movflags "+faststart" \    # Moves moov atom to start for streaming
  -y output.mp4
```

The `-movflags +faststart` flag is **essential** for AVPlayer to quickly initialize playback. Without it, AVPlayer must download the entire file to find metadata.

---

## Evidence & Diagnostic Logs

### Successful Upload (Current Broken Video)

```
🎥 Processing standalone video - Asset ID: 13E9923F-EC97-45D3-A201-FD38E7E5BAF3/L0/001
🎬 Transcoding video to MP4...
ERROR AppleProResHW:  45 :  AppleProResHW_CheckPlatform (): IOServiceGetMatchingService failed
✅ Transcoded to MP4: 22266321 bytes
✅ Transcoded standalone video: 22266321 bytes
📦 Created video metadata - Type: VIDEO, Size: 22266321 bytes
📤 Sending to backend:
   Collection ID: 0c68c7c9-6839-47c6-879d-24372a23d68a
   Total items: 1
   [0] mediaType: VIDEO, hasVideo: true
       Video - contentType: video/mp4, size: 22266321
🚀 Preparing Upload
✅ Upload 1/2 complete
✅ Upload 2/2 complete
✅ Video uploaded for index 0
🎬 Backend processing started for 1 items
```

### Attempted Playback (Failure)

```
🔄 Downloading and caching video: 8ca1266d-55a3-4ec5-9dd5-114f2ca1580d
⬇️ Downloading video: 8ca1266d-55a3-4ec5-9dd5-114f2ca1580d
💾 Cached video: 8ca1266d-55a3-4ec5-9dd5-114f2ca1580d (21744KB)
✅ File verification: exists, size=22266321 bytes
📄 Content-Type: video/mp4
✅ Video cached at: /var/mobile/.../VideoCache/8ca1266d-55a3-4ec5-9dd5-114f2ca1580d.mp4

🔍 Validating video file with AVAsset...
📹 AVAsset validation results:
   ✅ Is playable: true
   ✅ Duration: 6.835 seconds
   ✅ Total tracks: 7
   📊 ALL TRACKS:
      Track 0: ID=1, Type=soun, Enabled=true
      Track 1: ID=2, Type=vide, Enabled=true
      Track 2: ID=3, Type=meta, Enabled=true
      Track 3: ID=4, Type=meta, Enabled=true
      Track 4: ID=5, Type=meta, Enabled=true
      Track 5: ID=6, Type=meta, Enabled=true
      Track 6: ID=7, Type=meta, Enabled=true
   🎬 Video tracks: 1
      Track 0:
         Codec: avc1
         Size: 2160.0x3840.0
   🔊 Audio tracks: 1

✅ Audio session configured for playback
🎬 Created AVPlayer, waiting for ready status
   Player item status: 0
   ✅ No error on player item
   Video track enabled: true
⏳ Waiting for video to become ready...
📊 Video status changed to: 0
⏱️ Video loading timed out after 15.0s
```

### FigApplicationStateMonitor Errors

```
<<<< Async >>>>  signalled err= 18,446,744,073,709,538,831  at <>: 3,919
<<<< FigApplicationStateMonitor >>>> signalled err= 18,446,744,073,709,532,185
```

These CoreMedia framework errors typically indicate:
- Video format incompatibility with AVPlayer
- Missing or malformed moov atom
- Incorrect streaming metadata

---

## Key Files Modified

### iOS (Swift)

1. **`LivePhotoHelper.swift`**
   - Contains video extraction and transcoding logic
   - Lines 233-272: `transcodeToMP4()` function using `AVAssetExportSession`
   - Current preset: `AVAssetExportPreset1920x1080`

2. **`NetworkVideoPlayerView.swift`**
   - Auto-play video player component
   - Lines 128-245: Video loading with timeout and error handling
   - Uses `VideoCache` for local caching

3. **`NetworkLivePhotoPlayerView.swift`**
   - Long-press Live Photo playback
   - Similar video loading logic to NetworkVideoPlayerView

4. **`VideoCache.swift`**
   - Actor-based video caching system
   - Downloads from S3 and saves with `.mp4` extension
   - LRU eviction, 500MB max cache, 7-day expiration

### Backend (Kotlin)

1. **`ProcessingServiceImpl.kt`**
   - Lines 150-219: `processVideo()` with ffmpeg
   - Creates 720p and 360p versions
   - Uses `-movflags +faststart` for streaming

2. **`PhotoServiceImpl.kt`**
   - Lines 147-199: Video upload URL generation
   - Line 311: Validates `contentType == "video/mp4"`
   - Creates presigned URLs for base, medium, low quality paths

3. **`ProcessingListener.kt`**
   - Kafka listener on `"new-media-created"` topic
   - Triggers video processing asynchronously

---

## Proposed Solutions

### Option 1: Upload Original Video Without Client Transcoding (RECOMMENDED)

**Approach:**
1. Remove `AVAssetExportSession` transcoding from iOS
2. Extract raw video data from Live Photo/video asset
3. Write to temporary file as-is (MOV format)
4. Upload with `video/quicktime` or `video/mp4` content-type
5. Let backend ffmpeg handle all processing

**Pros:**
- Eliminates broken client-side transcoding
- Backend ffmpeg proven to work for photos
- Properly optimized with `-movflags +faststart`
- Consistent processing pipeline

**Cons:**
- Larger upload sizes (original video vs transcoded)
- Need to verify backend accepts MOV files
- May need backend content-type validation change

**Required Changes:**
```swift
// LivePhotoHelper.swift
// Instead of transcodeToMP4(), just save raw data:
static func extractVideoForUpload(from asset: PHAsset) async throws -> URL {
    // Extract paired video resource
    // Write directly to temp file
    // Return URL without transcoding
}
```

```kotlin
// PhotoServiceImpl.kt (if needed)
if (contentType != "video/mp4" && contentType != "video/quicktime") {
    throw LogBadRequestException("invalid content type")
}
```

### Option 2: Debug AVAssetExportSession Settings

**Approach:**
1. Research exact ffmpeg parameters backend uses
2. Try to replicate with AVAssetExportSession settings
3. Experiment with different AVFoundation APIs

**Pros:**
- Smaller upload sizes (transcoded)
- Faster uploads on slow connections

**Cons:**
- Already tried 4 different presets - all failed
- `AVAssetExportSession` doesn't expose moov atom control
- May be fundamentally incompatible with AVPlayer's requirements
- Time-consuming trial and error

### Option 3: Backend-Only Processing (No Client Upload)

**Approach:**
1. Backend accepts original MOV files
2. Transcode on backend before storing
3. iOS only uploads original assets

**Pros:**
- Complete control over video format
- Guaranteed compatibility
- Single source of truth for processing

**Cons:**
- Requires significant backend changes
- Longer upload times for users
- More backend processing load

---

## Testing Validation Checklist

When testing any solution, verify:

- [ ] Video uploads successfully to S3
- [ ] Backend Kafka processing completes
- [ ] 720p and 360p versions created
- [ ] Video downloads successfully
- [ ] AVAsset reports `isPlayable = true`
- [ ] **AVPlayer status transitions to 1 (ReadyToPlay)**
- [ ] Video auto-plays in NetworkVideoPlayerView
- [ ] Long-press playback works in NetworkLivePhotoPlayerView
- [ ] No CoreMedia/FigApplicationStateMonitor errors
- [ ] Video loops smoothly
- [ ] Audio session configured correctly
- [ ] No memory leaks during playback

---

## Questions to Investigate

1. **Does backend actually receive and process the uploaded video?**
   - Check Kafka logs for `"new-media-created"` messages
   - Verify ffmpeg processing completes
   - Confirm 720p/360p files exist in S3

2. **Are we downloading the processed version or original?**
   - Current code requests `video.path` (original)
   - Should we use `video.medQualityPath` (720p) or `video.lowQualityPath` (360p)?
   - These would have been processed by ffmpeg with proper flags

3. **What happens if we download the backend-processed 720p version?**
   - Backend creates it with `-movflags +faststart`
   - Should be properly formatted for streaming
   - **This might already work!**

4. **Did QuickTime content-type actually fail, or was it another issue?**
   - Document mentions it "didn't work"
   - What was the specific error?
   - Was backend rejecting it, or was it a client issue?

---

## Immediate Next Step (QUICK WIN?)

**TEST: Download backend-processed version instead of original**

The backend creates 720p and 360p versions with proper ffmpeg optimization. We might already be able to play videos if we download these instead of the original!

**Change needed:**
```swift
// Currently downloading from imageUrl/videoUrl (original upload)
// Try downloading from medQualityUrl or lowQualityUrl (ffmpeg processed)

// In the view code, change:
let videoURL = videoUrl?.url(for: quality)  // This gets original

// To:
let videoURL = videoUrl?.medQualityUrl  // This gets ffmpeg-processed 720p
```

**Why this might work:**
- Backend ffmpeg uses `-movflags +faststart` ✅
- Creates properly formatted MP4 for streaming ✅
- Already tested and working for other platforms ✅
- Zero code changes needed on backend ✅

---

## Additional Context

### AVPlayer Status Codes
- `0` = Unknown (initial state)
- `1` = ReadyToPlay
- `2` = Failed

### Content-Type Headers
- `video/mp4` - MPEG-4 video
- `video/quicktime` - Apple QuickTime MOV
- Both are valid, but backend currently only accepts `video/mp4`

### S3 URL Structure
Backend creates presigned URLs for three quality levels:
- `path/${videoId}` - Original upload
- `path/med_${videoId}` - 720p processed
- `path/low_${videoId}` - 360p processed

### moov Atom Optimization
- Default MP4: moov atom at end (requires full download)
- Optimized MP4: moov atom at start (enables streaming)
- ffmpeg flag: `-movflags +faststart`
- AVAssetExportSession: No equivalent option exposed

---

## Related Files Reference

### iOS
```
Frontend/iOS/Clique/Clique/
├── Helpers/Photos/LivePhotoHelper.swift
├── Helpers/VideoCache.swift
├── Components/Kingfisher/
│   ├── NetworkVideoPlayerView.swift
│   └── NetworkLivePhotoPlayerView.swift
├── Model/DTOs/PhotoUrls.swift (MediaUrls)
└── Core/Create/
    ├── ViewModel/CreateViewModel.swift
    └── View/CollectionPhotosPicker/
```

### Backend
```
Backend/kotlin/clique_services/alpha/webapp/src/main/kotlin/com/clique/alpha/webapp/
├── service/
│   ├── photo/PhotoServiceImpl.kt
│   └── processing/ProcessingServiceImpl.kt
├── pubsub/processing/ProcessingListener.kt
└── entity/
    ├── Photo.kt
    └── Video.kt
```

---

## Git Context

- **Current Branch:** `rt/livephotos-videos`
- **Main Branch:** `main`
- **Recent Commits:**
  - `d5aeb74b` - Update Claude Code settings to allow Ref MCP tools
  - `33d61ee1` - Temporarily disable app bricked check for development
  - `c8424f0a` - Fix upload progress calculation and add swipe-to-dismiss
  - `8fad897f` - Update views to support Live Photo detection and single quality upload

---

## Contact & Handoff Notes

This issue has been under investigation for multiple attempts across different transcoding presets. The most promising next step is testing whether the backend-processed 720p/360p versions (created with ffmpeg's `-movflags +faststart`) already work with AVPlayer.

If that doesn't work, the recommended approach is to eliminate client-side transcoding entirely and upload original video files for backend processing.

All diagnostic logging has been cleaned up in `NetworkVideoPlayerView.swift` to production-ready state, with only essential logs remaining.
