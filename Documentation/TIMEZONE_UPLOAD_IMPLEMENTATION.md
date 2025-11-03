# Timezone Extraction on Upload - Implementation

## Summary

We've implemented **timezone offset extraction during photo upload** from the iOS client. The frontend now extracts timezone information from photo EXIF metadata and stores it ready to send to the backend.

## What Was Implemented

### 1. New Helper: PHAssetMetadataHelper.swift

Extracts timezone offset from PHAsset's EXIF metadata:

```swift
// Extract timezone from photo library asset
let offset = await PHAssetMetadataHelper.extractTimezoneOffset(from: asset)
// Returns: "-0400", "+0530", etc. or nil
```

**How it works:**
1. Requests full image data from PHImageManager
2. Reads EXIF metadata using ImageIO
3. Checks `OffsetTimeOriginal` field (most accurate)
4. Falls back to GPS-based geocoding if no EXIF offset
5. Returns ISO 8601 format: `"-0400"`, `"+0530"`, etc.

### 2. Updated Data Flow

**CreateViewModel.swift**:
- Added `selectedImagesTimezoneOffsets: [String?]` array
- Updated `processedImageData` to include timezone offset
- Updated `addProcessedAssets()` to accept timezone offset
- Updated `clearAllSelections()` and `reset()` to clear timezone offsets

**PhotoProcessingHelper.swift**:
- Added timezone extraction to `processAssetsFromPicker()
- Extracts timezone offset for each asset concurrently
- Stores timezone offset alongside image and date

### 3. Current Status

✅ **Implemented**:
- Timezone extraction from EXIF metadata
- Timezone storage in CreateViewModel
- Timezone available in upload flow

❌ **Not Yet Done** (Requires Backend Changes):
- Sending timezone offset to backend API
- Backend storing timezone offset in database
- Backend returning timezone offset in responses

## How It Works

### Photo Selection Flow (with Timezone)

```
1. User selects photos from library
   └─> PhotoProcessingHelper.processAssetsFromPicker()

2. For each PHAsset:
   ├─> Load image
   ├─> Get creation date (Date object)
   └─> Extract timezone offset from EXIF metadata
       └─> PHAssetMetadataHelper.extractTimezoneOffset(asset)
           ├─> Read EXIF["OffsetTimeOriginal"] → "-0400" ✅
           └─> Fallback: GPS geocoding → timezone

3. Store in CreateViewModel:
   ├─> selectedImages: [UIImage]
   ├─> selectedImagesDates: [Date]
   └─> selectedImagesTimezoneOffsets: [String?]  // NEW!
```

### Upload Flow (Ready for Backend)

```
PhotoProcessingHelper.processSelectedPhotosForUpload()
   │
   ├─> For each (image, date, timezoneOffset):
   │   └─> Create PhotoVideoDate object
   │       ├─> dateCreated: convertFromDate(date)  // UTC string
   │       └─> timezoneOffset: offset  // "-0400" (READY TO SEND)
   │
   └─> Send to backend via CollectionService
```

## What's Missing

### Backend API Schema Update Needed

The frontend is ready to send timezone offset, but the backend API needs updating:

**1. Update openapi.yaml:**
```yaml
PhotoVideoDate:
  properties:
    dateCreated:
      type: string
      format: date-time
    timezoneOffset:  # ADD THIS
      type: string
      nullable: true
      pattern: '^[+-]\d{4}$'
      example: "-0400"
```

**2. Update backend model to accept `timezoneOffset`**

**3. Store timezone offset in database**

**4. Return timezone offset in API responses**

### To Complete the Implementation

**Option A: Send Now (Backend Ignores)**
- Update PhotoProcessingHelper line 135-140 to include timezone offset
- Backend will ignore the field until it's added to schema
- No harm, forward-compatible

**Option B: Wait for Backend**
- Keep frontend ready
- Update backend first
- Then enable frontend to send timezone

## Benefits of This Approach

1. **Accurate Timezone**: Reads from EXIF, doesn't guess
2. **Better Than Video Extraction**: Works for static photos too
3. **Upload-Time Extraction**: No need to download video later
4. **Backend-Ready**: Frontend prepared for when backend supports it

## Testing Instructions

Once backend is updated:

1. **Select a photo with timezone metadata** (photo taken in different timezone)
2. **Upload to Clique**
3. **Verify timezone offset is sent** in API request
4. **Verify timezone offset is stored** in database
5. **Verify timezone offset is returned** in API response
6. **Verify date displays correctly** in original timezone

## Files Modified

### New Files:
- `Helpers/Photos/PHAssetMetadataHelper.swift` - Extract timezone from PHAsset

### Modified Files:
- `Utils/Utils.swift` - Added `extractDateAndTimezoneOffset()` function
- `Core/Create/ViewModel/CreateViewModel.swift` - Added timezone offset storage
- `Core/Create/Helpers/PhotoProcessingHelper.swift` - Extract timezone during photo processing

## Next Steps

1. **Update Backend**: Add `timezone_offset` field to API and database
2. **Update PhotoProcessingHelper**: Pass timezone offset to PhotoVideoDate
3. **Test End-to-End**: Verify timezone preservation works
4. **Update Display Logic**: Use backend-provided timezone offset (faster than video extraction)

## Comparison: Upload vs Display Extraction

| Aspect | Upload Extraction (This PR) | Display Extraction (Previous) |
|--------|----------------------------|-------------------------------|
| **Works for static photos** | ✅ Yes | ❌ No (needs video) |
| **Works for Live Photos** | ✅ Yes | ✅ Yes |
| **Works for videos** | ✅ Yes | ✅ Yes |
| **Requires backend changes** | ✅ Yes | ❌ No |
| **Persists across devices** | ✅ Yes | ❌ No (cache only) |
| **Extraction timing** | Once at upload | Every time displayed |
| **Performance** | ⚡ Fast (EXIF read) | 🐌 Slow (video download) |

**Recommendation**: Implement both!
- Upload extraction for complete solution
- Display extraction as fallback for old data without timezone

---

**Status**: ✅ Frontend ready, waiting for backend schema update
