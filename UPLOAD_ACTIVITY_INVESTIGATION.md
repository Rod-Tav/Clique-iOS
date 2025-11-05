# InAppUploadActivityView Investigation Report

## Summary

The `InAppUploadActivityView` displays upload progress using Live Activity data. There are several issues with the current implementation:

1. **Fallback view appears after completion** - When the Live Activity ends, `currentActivity` becomes `nil`, triggering the fallback view instead of showing the completion state
2. **No swipe-to-dismiss gesture** - The view lacks the gesture handling for user dismissal
3. **Unclear state transitions** - The `showNav` and `showRetry` logic isn't clearly consolidated

---

## File Structure

### Current Implementation
- **Location**: `/Users/rodtavangar/Documents/Xcode/clique/Frontend/iOS/Clique/Clique/Core/Create/View/InAppUploadActivityView.swift`
- **Lines**: 257 total
- **Usage**: Displayed in `MainTabView.swift` (lines 182-199)

### Related Files
- **LiveActivityManager**: `/Clique/Managers/LiveActivityManager.swift` - Manages activity lifecycle
- **SwipeToDismiss Modifier**: `/Clique/Utils/SwipeDownToDismiss.swift` - Gesture implementation
- **GestureConstants**: `/Clique/Helpers/Gestures/GestureConstants.swift` - Shared gesture constants
- **Old UploadProgressView**: Git commit `4b376aed` - Had working swipe-to-dismiss implementation

---

## Current State Logic Analysis

### How showNav=true is Triggered

In `MainTabView.swift` (line 186):
```swift
showNav: !isUploading && !viewModel.collectionId.isEmpty
```

**Conditions for "View Collection" button to appear:**
1. `isUploading == false` - Upload has completed or failed
2. `viewModel.collectionId` is not empty - Collection was successfully created

**When this happens:**
- Upload finishes → `isUploading` set to `false` in MainTabView
- Live Activity is ended with `.after(4.0)` dismissal policy
- `showNav` becomes `true`
- "View Collection" button appears

### How showRetry=true is Triggered

In `MainTabView.swift` (line 187):
```swift
showRetry: viewModel.uploadFailed
```

**When retry button appears:**
- If any images failed to upload → `viewModel.uploadFailed == true`
- Retry button triggers `viewModel.retryUploadImages()`

### Current Button Logic (Lines 46-106)

```swift
VStack(spacing: 12) {
    // Show "View Collection" if showNav=true
    if showNav {
        Button { /* nav action */ }
        
    // Show "Retry" if showRetry=true
    if showRetry {
        Button { /* retry action */ }
        
    // Show dismiss button if NEITHER showNav NOR showRetry
    if !showNav && !showRetry {
        Button { showUploading = false }
    }
}
```

**Issue:** The fallback progress view appears BETWEEN the Live Activity ending and the buttons showing.

---

## Why Fallback View Shows After Completion

### The Problem

In InAppUploadActivityView (lines 38-43):
```swift
if let activity = LiveActivityManager.shared.currentActivity {
    customProgressView(activity: activity)
} else {
    // Fallback if Live Activity isn't available
    fallbackProgressView
}
```

### Timeline of Events

1. **During Upload** (seconds 0-30):
   - `isUploading = true`
   - Live Activity is active
   - `currentActivity` is not nil
   - `customProgressView` displays

2. **Upload Complete** (second 30+):
   - `isUploading = false` (set in MainTabView after viewModel.uploadToCollection())
   - Live Activity called with `.after(4.0)` dismissal policy
   - For the next 4 seconds: `currentActivity` is still not nil (Activity object exists)
   - `customProgressView` still displays with final state

3. **After Dismissal (second 34+)**:
   - ActivityKit system removes the activity
   - `currentActivity` becomes nil
   - **FALLBACK VIEW APPEARS** - This is unexpected!
   - User sees generic "Uploading... Processing your photos" message
   - Only THEN do buttons appear based on `showNav`/`showRetry`

### Why This Happens

The `fallbackProgressView` (lines 208-228) has no logic to check if the upload is complete. It just shows a generic progress spinner and "Processing your photos" text regardless of whether upload succeeded.

**The fallback view should NOT appear after upload completes.**

---

## Old UploadProgressView Implementation (Commit 4b376aed)

### Key Differences

```swift
// OLD: Single ZStack-based approach
ZStack(alignment: .topLeading) {
    Button { /* nav action */ }
    
    VStack(alignment: .leading) {
        HStack {
            if showNav {
                // Show "Tap to go to collection"
            } else if totalFlicks == 0 {
                // Show processing spinner
            } else {
                // Show upload progress
            }
        }
        // Progress bar (only when !showNav)
    }
}
.frame(height: 48)
.swipeDownToDismiss(isPresented: $showUploading)
```

**Benefits of old approach:**
1. Consolidated view logic - Single if/else tree
2. Swipe-to-dismiss built in
3. No separate fallback view
4. Cleaner state transitions

### Swipe-to-Dismiss Implementation

Used the `.swipeDownToDismiss(isPresented:)` modifier from `SwipeDownToDismiss.swift`:

```swift
func swipeDownToDismiss(isPresented: Binding<Bool>, isSwiping: Binding<Bool>? = nil) -> some View {
    self.modifier(SwipeToDismissWithBindingModifier(isPresented: isPresented, isSwiping: isSwiping))
}
```

**How it works:**
- `DragGesture` with `minimumDistance: GestureConstants.minimumRecognitionDistance` (10 points)
- Only recognizes downward swipes: `guard abs(value.translation.width) < GestureConstants.maximumHorizontalDeviation`
- Dismissal threshold: `GestureConstants.dismissThresholdBasic` (10 points)
- Velocity dampening factor: `GestureConstants.velocityDampening` (5)
- Formula: `finalHeight = translation.height + (velocity.height / 5)`
- Animates off-screen with `.easeInOut(duration: 0.3)`
- Then sets `showUploading = false` to dismiss

---

## SwipeToDismiss Modifier Details

### Location
`/Users/rodtavangar/Documents/Xcode/clique/Frontend/iOS/Clique/Clique/Utils/SwipeDownToDismiss.swift`

### Two Variants

**1. SwipeToDismissModifier** (uses environment dismiss)
```swift
@State private var dismissOffset: CGSize = .zero

.offset(dismissOffset)
.simultaneousGesture(
    DragGesture(minimumDistance: 10)
        .onChanged { value in
            if value.translation.height > 10 && abs(value.translation.width) < 20 {
                dismissOffset = CGSize(width: 0, height: value.translation.height)
            }
        }
        .onEnded { value in
            let height = value.translation.height + (value.velocity.height / 5)
            if height > 10 {
                dismiss()  // Uses @Environment(\.dismiss)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dismissOffset = .zero
                }
            }
        }
)
```

**2. SwipeToDismissWithBindingModifier** (uses binding - recommended for this use case)
```swift
@Binding var isPresented: Bool
@State private var dismissOffset: CGFloat = 0

.offset(y: dismissOffset)
.simultaneousGesture(
    DragGesture(minimumDistance: 10)
        .onChanged { value in
            guard abs(value.translation.width) < 20 else { return }
            dismissOffset = max(0, value.translation.height)
        }
        .onEnded { value in
            let height = value.translation.height + (value.velocity.height / 5)
            if height > 10 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    dismissOffset = UIScreen.main.bounds.height
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                    dismissOffset = 0
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dismissOffset = 0
                }
            }
        }
)
```

### Key Features

| Feature | Value |
|---------|-------|
| Gesture Type | DragGesture with simultaneousGesture |
| Minimum Recognition | 10 points |
| Horizontal Tolerance | 20 points max deviation |
| Dismiss Threshold | 10 points |
| Velocity Dampening | Divide by 5 |
| Dismissal Animation | 0.3s easeInOut |
| Reset Animation | 0.2s easeInOut |

---

## Recommended View Structure

### Consolidated if/else Logic

Instead of separate `customProgressView`, `fallbackProgressView`, and button logic, consolidate into one view:

```swift
var body: some View {
    VStack(spacing: 12) {
        // Informational message
        Text("You can leave the app - we'll continue uploading in the background")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 4)

        // UNIFIED PROGRESS VIEW LOGIC
        if showNav {
            // COMPLETION STATE: Show "View Collection" button
            completionView
        } else if showRetry {
            // ERROR STATE: Show retry button
            errorView
        } else {
            // UPLOADING STATE: Show progress
            progressView
        }
        
        // ACTION BUTTONS - Consolidated
        bottomActionButtons
    }
    .padding(.horizontal, 8)
    .swipeDownToDismiss(isPresented: $showUploading)  // ADD THIS
}

// MARK: - View Components

private var progressView: some View {
    VStack(spacing: 12) {
        if let activity = LiveActivityManager.shared.currentActivity {
            customProgressView(activity: activity)
        } else {
            // Simple progress state when activity nil but showNav=false
            HStack(spacing: 12) {
                CliqueProgressView(size: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uploading...")
                    Text("Processing your photos")
                }
                Spacer()
            }
            .padding(16)
            .primaryBackground()
            .roundCorners(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

private var completionView: some View {
    VStack(spacing: 12) {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upload Complete")
                Text("View your collection")
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
        }
        .padding(16)
        .primaryBackground()
        .roundCorners(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

private var errorView: some View {
    VStack(spacing: 12) {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upload Failed")
                Text("Some photos couldn't upload")
            }
            Spacer()
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
        }
        .padding(16)
        .primaryBackground()
        .roundCorners(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

private var bottomActionButtons: some View {
    VStack(spacing: 12) {
        if showNav {
            Button { /* navigate */ }
                .buttonStyle(...)
        }
        
        if showRetry {
            Button { retryAction() }
                .buttonStyle(...)
        }
        
        if !showNav && !showRetry {
            Button { showUploading = false }
                .buttonStyle(...)
        }
    }
    .padding(.horizontal, 8)
}
```

---

## Summary: Key Insights

### The Three Problems

1. **Fallback view appears after completion**
   - Caused by: Live Activity being nil after dismissal policy expires
   - Solution: Don't show fallback when `showNav` or `showRetry` is true

2. **No swipe-to-dismiss gesture**
   - Missing: `.swipeDownToDismiss(isPresented: $showUploading)` modifier
   - Solution: Add the modifier from `SwipeDownToDismiss.swift`

3. **Scattered state logic**
   - Current: Multiple if statements for buttons, separate progress views
   - Solution: Consolidate into single if/else tree (uploading → error → completion)

### Implementation Priority

1. **High**: Add swipe-to-dismiss modifier (1 line)
2. **High**: Fix fallback view logic (2-3 lines)
3. **Medium**: Consolidate view structure for clarity
4. **Low**: Enhance completion/error state UI

### Testing Checklist

- [ ] Upload succeeds → shows "View Collection" button after Live Activity ends
- [ ] Upload fails → shows "Retry" button immediately
- [ ] Swipe down during upload → dismisses view
- [ ] Swipe up or sideways → no dismiss
- [ ] Tap outside → no dismiss (sheet-like behavior)
- [ ] Retry after failure → starts new upload

