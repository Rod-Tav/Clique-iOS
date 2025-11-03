# Backend Team: Video Processing Issue

**Date:** October 19, 2025
**Priority:** High
**Reporter:** iOS Team

---

## Problem

Videos uploaded from iOS won't play after backend processing. AVPlayer status stuck at 0, times out after 15 seconds.

**What Changed:** iOS now uploads raw MOV files (renamed to `.mp4`) instead of broken client-transcoded videos.

---

## Test Video Details

**Video ID:** `b9078909-887a-48c2-bdcc-568ecacf7c88`
**Collection ID:** `0238041d-0647-42ff-b4b7-28730a4d1eec`
**Upload Time:** ~22:42 UTC, Oct 19, 2025
**Original:** 20.9MB MOV file (uploaded as `.mp4`)
**Backend 720p:** 1.4MB (`med_74d1b8f6-f8d6-4c31-bc29-136532b7b144`)

---

## Questions for Backend

### 1. Did ffmpeg process this video successfully?

Check Kafka logs around 22:42 UTC for:
- Did processing complete without errors?
- Were 720p/360p versions created in S3?

### 2. What codec is the output using?

Run: `ffprobe med_74d1b8f6-f8d6-4c31-bc29-136532b7b144`

**Expected:** Video codec = `h264` (NOT `hevc` or `prores`)
**Critical:** If not H.264, iOS AVPlayer won't play it.

### 3. Is ffmpeg missing the video codec flag?

Current command in `ProcessingServiceImpl.kt:169`:
```kotlin
ffmpeg -i input.mp4 \
  -vf "scale=-2:720" \
  -b:v "1500k" \
  -c:a "aac" -b:a "128k" \      ← Audio codec specified
  -movflags "+faststart" \
  -y output.mp4
```

**Missing:** `-c:v libx264` (video codec)

Without this, ffmpeg may copy the source codec from the MOV file, which could be incompatible with iOS.

---

## Recommended Fix

Add `-c:v libx264` to force H.264 encoding:

```kotlin
// ProcessingServiceImpl.kt:169 and :183
ffmpeg -i input.mp4 \
  -c:v libx264 \                    ← ADD THIS
  -vf "scale=-2:720" \
  -b:v "1500k" \
  -c:a "aac" -b:a "128k" \
  -movflags "+faststart" \
  -y output.mp4
```

Apply to both 720p and 360p commands.

---

## Optional: Accept QuickTime Content-Type

**Current:** `PhotoServiceImpl.kt:311` only accepts `video/mp4`

**Change to:**
```kotlin
if (contentType != "video/mp4" && contentType != "video/quicktime") {
    throw LogBadRequestException("invalid content type")
}
```

This lets iOS upload with honest `video/quicktime` header.

---

## iOS Testing Checklist (After Fix)

- [ ] Upload new video
- [ ] Wait 60s for backend processing
- [ ] Verify AVPlayer status = 1 (ReadyToPlay)
- [ ] Video auto-plays successfully

---

## Files to Check

1. `ProcessingServiceImpl.kt:150-219` - Video processing
2. `PhotoServiceImpl.kt:311` - Content-type validation
3. Kafka logs - Processing errors
4. S3 - Check if processed files exist

**iOS branch:** `rt/livephotos-videos` (no backend changes made)
