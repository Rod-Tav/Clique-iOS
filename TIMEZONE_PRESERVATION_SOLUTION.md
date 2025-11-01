# Timezone Preservation Solution (Frontend-Only)

## Problem

When photos/videos are uploaded to Clique with timezone metadata (e.g., "October 21, 8:05 PM EDT"), the backend only stores the UTC timestamp. When displayed, dates are converted to the viewer's local timezone, showing incorrect times.

**Example:**
- Photo taken: October 21, 8:05 PM Eastern (-0400)
- Stored in DB: October 22, 00:05 UTC
- Displayed to Pacific viewer: October 21, 5:05 PM PDT ❌ (Wrong! Should be 8:05 PM EDT)

## Solution (Without Backend Changes)

Since we preserve timezone in video metadata for Live Photos and videos, we can extract it client-side and use it for display.

### What Works
- ✅ **Live Photos**: Timezone extracted from video component, displayed correctly
- ✅ **Standalone Videos**: Timezone extracted from video file, displayed correctly
- ❌ **Static Photos**: Still show in viewer's local timezone (no video to extract from)

### Implementation

#### 1. New Helper: VideoMetadataHelper.swift

Extracts timezone offset from video metadata:

```swift
// Extract timezone from video
if let offset = await VideoMetadataHelper.extractTimezoneOffset(from: videoURL) {
    // Returns "-0400", "+0530", etc.
}
```

Reads QuickTime creation date metadata which includes timezone:
```
com.apple.quicktime.creationdate = "2025-10-21T20:05:51-0400"
                                                        ^^^^^^
                                                        Timezone offset
```

#### 2. Timezone-Aware Date Formatting (Utils.swift)

New functions that format dates in the original timezone:

```swift
// Format date in original timezone
formatDateInOriginalTimezone(date, timezoneOffset: "-0400", format: "MMMM d, yyyy h:mm a")
// Result: "October 21, 2025 8:05 PM" (uses -0400 timezone, not viewer's timezone)

// Convenience wrappers
formatDateMMMMdYYYYWithTimezone(date, timezoneOffset: "-0400")
formatDateHHmmWithTimezone(date, timezoneOffset: "-0400")
```

#### 3. CollectionImage Model Updates

Added `cachedTimezoneOffset` property for runtime caching:

```swift
struct CollectionImage {
    // ... existing properties
    var cachedTimezoneOffset: String? = nil  // Runtime cache, not persisted
}
```

#### 4. CollectionImageStore Caching

Added methods to cache timezone offsets per session:

```swift
// Cache timezone for an image
collectionImageStore.cacheTimezoneOffset(for: imageId, offset: "-0400")

// Retrieve cached timezone
collectionImageStore.getCachedTimezoneOffset(for: imageId)
```

#### 5. DateMediaTypeLabel Component

Automatically extracts timezone and uses it for display:

```swift
.task(id: image.id) {
    if (image.isLivePhoto || image.isVideo), let url = image.videoUrls?.videoUrl(for: .medium) {
        // Check cache first
        if let cached = collectionImageStore.getCachedTimezoneOffset(for: image.id) {
            timezoneOffset = cached
        } else {
            // Extract from video metadata
            if let offset = await VideoMetadataHelper.extractTimezoneOffset(from: url) {
                timezoneOffset = offset
                // Cache for future use
                collectionImageStore.cacheTimezoneOffset(for: image.id, offset: offset)
            }
        }
    }
}

// Use timezone-aware formatting
private var formattedDate: String {
    let datePart = formatDateMMMMdYYYYWithTimezone(image.date, timezoneOffset: timezoneOffset)
    let timePart = formatDateHHmmWithTimezone(image.date, timezoneOffset: timezoneOffset)
    return "\(datePart) • \(timePart)"
}
```

### How It Works

1. **First View**: When a Live Photo/video is displayed
   - Component checks cache → not found
   - Downloads video file (already cached by VideoCache)
   - Reads QuickTime metadata to extract timezone offset
   - Caches offset in CollectionImageStore
   - Displays date using original timezone

2. **Subsequent Views**: When same image is viewed again
   - Component checks cache → found!
   - Uses cached timezone offset immediately
   - No video metadata extraction needed

3. **Date Display**: Always uses timezone-aware formatter
   - If timezone offset available → use original timezone
   - If not available (static photos) → fall back to viewer's timezone

### Limitations

**Without Backend Changes:**
- ❌ Static photos can't preserve timezone (no video metadata to read)
- ❌ Timezone cache doesn't persist across app launches
- ❌ Timezone cache doesn't sync across devices
- ❌ Requires downloading video file to extract timezone

**With Future Backend Changes:**
When backend adds `timezone_offset` field:
- ✅ All media types (photos, Live Photos, videos) preserve timezone
- ✅ Timezone persists across sessions and devices
- ✅ No need to download video to get timezone
- ✅ Timezone available immediately on page load

### Files Modified

1. **New Files:**
   - `Helpers/VideoMetadataHelper.swift` - Extract timezone from video metadata

2. **Modified Files:**
   - `Utils/Utils.swift` - Added timezone-aware date formatting functions
   - `Model/ClCollection.swift` - Added `cachedTimezoneOffset` property
   - `Model/Stores/CollectionImageStore.swift` - Added caching methods
   - `Components/Simple/DateMediaTypeLabel.swift` - Extract and use timezone

### Testing

Test on a real iPhone device (timezone extraction only works with actual video files):

1. **Upload a Live Photo from another timezone**
   - Photo should preserve metadata during upload

2. **View the Live Photo in collection detail**
   - Should extract timezone from video
   - Should display time in original timezone (e.g., "8:05 PM EDT")
   - Should NOT show time in your current timezone (e.g., "5:05 PM PDT")

3. **Save Live Photo to device**
   - Saved Live Photo should have correct creation date in Photos app

4. **View same Live Photo again**
   - Should use cached timezone (no re-extraction)
   - Should still display correctly

### Future Backend Migration Path

When backend adds timezone support:

1. **Backend adds `timezone_offset` column** to database
2. **API returns timezone** with each photo/video
3. **Frontend uses API timezone** first, falls back to video extraction for old data
4. **Static photos** get timezone preservation too

Migration is seamless - existing code continues to work, just gets faster and more accurate.

## Summary

This frontend-only solution provides timezone preservation for **Live Photos and videos** by extracting timezone from video metadata. While not perfect (static photos still use viewer's timezone), it significantly improves the user experience without requiring backend changes.

**For complete timezone preservation across all media types**, backend changes will eventually be needed.
