# Clique iMessage Extension Implementation Report

## Overview

This document details the implementation of the Clique iMessage extension, which allows users to browse and share Clique content directly within the Messages app.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Main Clique App                          │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ CacheSyncService │  │AuthTokenSyncHelper│                 │
│  └────────┬────────┘  └────────┬────────┘                   │
│           │                     │                            │
│           ▼                     ▼                            │
│  ┌──────────────────────────────────────────┐               │
│  │           App Group Container             │               │
│  │  ┌────────────┐  ┌────────────────────┐  │               │
│  │  │ Auth Token │  │ Cached Data (JSON) │  │               │
│  │  └────────────┘  └────────────────────┘  │               │
│  └──────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  CliqueCore SPM Package                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │AppGroupManager│ │SharedAuthStorage│ │ExtensionCacheManager│ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ChatKeyGenerator│ │DeepLinkBuilder│ │   Cached Models    │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                CliqueMessages Extension                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            MessagesViewController                    │    │
│  │  (MSMessagesAppViewController - UIKit bridge)       │    │
│  └────────────────────────┬────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              ExtensionViewModel                      │    │
│  │  (@Observable state management)                      │    │
│  └────────────────────────┬────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               SwiftUI Views                          │    │
│  │  ExtensionRootView → CliqueListView                 │    │
│  │                    → CollectionListView             │    │
│  │                    → FlickGridView                  │    │
│  │                    → CreateCliqueView               │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Components Implemented

### 1. CliqueCore SPM Package

**Location:** `Packages/CliqueCore/`

A local Swift Package that provides shared functionality between the main app and the iMessage extension.

#### Models
| File | Purpose |
|------|---------|
| `CachedClique.swift` | Lightweight clique model for extension |
| `CachedCollection.swift` | Lightweight collection model |
| `CachedFlick.swift` | Lightweight flick model with media type |
| `CachedUser.swift` | Lightweight user model |
| `Visibility.swift` | Privacy visibility enum |

#### Storage & Utilities
| File | Purpose |
|------|---------|
| `AppGroupManager.swift` | Manages App Group container access (`group.com.cliquellc.clique`) |
| `SharedAuthStorage.swift` | Stores/retrieves Firebase auth tokens via Keychain in App Group |
| `ChatKeyGenerator.swift` | Generates deterministic chat keys from iMessage participant UUIDs using SHA256 |
| `ChatKeyStore.swift` | Persists chat key to clique ID mappings |
| `DeepLinkBuilder.swift` | Creates `clique://` deep link URLs for flicks, collections, and cliques |
| `ExtensionCacheManager.swift` | JSON-based cache for cliques, collections, flicks, and user data |
| `ColorTheme.swift` | Extension-specific color definitions |

### 2. Main App Integration

#### CacheSyncService
**Location:** `Clique/Services/CacheSyncService.swift`

Syncs main app data to the extension cache whenever data is fetched:

```swift
// Usage in main app
CacheSyncService.shared.syncCliques(cliques)
CacheSyncService.shared.syncCollections(collections, for: cliqueId)
CacheSyncService.shared.syncUser(user)
```

**Key Features:**
- Converts full app models to lightweight cached versions
- Handles visibility enum conversion between app and CliqueCore
- Thread-safe with Sendable conformance
- Async variants available for await syntax

#### AuthTokenSyncHelper
**Location:** `Clique/Services/Helpers/AuthTokenSyncHelper.swift`

Bridges Firebase authentication to the extension:

```swift
// Called during app initialization
AuthTokenSyncHelper.shared.startListening()
```

**Key Features:**
- Listens to Firebase auth state changes
- Syncs ID tokens to SharedAuthStorage
- Handles token refresh automatically
- Clears tokens on sign out

### 3. iMessage Extension Target

**Target:** `CliqueMessages`

#### MessagesViewController
**Location:** `CliqueMessages/MessagesViewController.swift`

The main entry point bridging Messages framework to SwiftUI:

**Responsibilities:**
- Manages extension lifecycle (willBecomeActive, didResignActive)
- Extracts conversation context and generates chatKey
- Handles presentation style transitions (compact ↔ expanded)
- Embeds SwiftUI views via UIHostingController
- Responds to memory warnings

**Chat Key Generation:**
```swift
let chatKey = ChatKeyGenerator.generate(
    localParticipant: conversation.localParticipantIdentifier,
    remoteParticipants: conversation.remoteParticipantIdentifiers
)
```

#### ExtensionViewModel
**Location:** `CliqueMessages/ViewModels/ExtensionViewModel.swift`

Central state management using @Observable:

**State Properties:**
- `isAuthenticated` - Auth status from SharedAuthStorage
- `presentationStyle` - Compact vs expanded mode
- `navigationState` - Current screen (cliqueList, collectionList, flickGrid, createClique)
- `cliques`, `collectionsForClique`, `flicks` - Cached data arrays
- `selectedClique`, `selectedCollection` - Current selections
- `chatKey` - Generated from conversation participants
- `isLoading`, `errorMessage` - UI state

**Navigation Methods:**
- `selectClique(_:)` - Navigate to collection list
- `selectCollection(_:)` - Navigate to flick grid
- `navigateBack()` - Pop navigation stack
- `navigateToCreateClique()` - Show create clique view

#### ExtensionImageLoader
**Location:** `CliqueMessages/Utilities/ExtensionImageLoader.swift`

Memory-efficient image loading designed for extension's ~30MB limit:

**Features:**
- NSCache for in-memory caching (50 images, 20MB limit)
- Disk cache in App Group container
- Automatic cache eviction on memory pressure
- Async/await API

#### ExtensionAsyncImage
**Location:** `CliqueMessages/Utilities/ExtensionAsyncImage.swift`

SwiftUI async image component using ExtensionImageLoader:

```swift
ExtensionAsyncImage(url: URL(string: flick.thumbUrl)) { phase in
    switch phase {
    case .loading:
        ProgressView()
    case .loaded(let image):
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failed:
        Image(systemName: "photo")
    }
}
```

#### MSMessageBuilder
**Location:** `CliqueMessages/Utilities/MSMessageBuilder.swift`

Creates rich iMessage bubbles with MSMessageTemplateLayout:

**Message Types:**
1. **Flick Message** - Share a single flick with thumbnail
2. **Collection Message** - Share an entire collection
3. **Clique Invite Message** - Invite someone to join a clique

**Layout Structure:**
```
┌─────────────────────────────────────┐
│          [Main Image]               │
│      imageTitle (overlay)           │
│     imageSubtitle (overlay)         │
├─────────────────────────────────────┤
│ caption                trailingCap  │
│ subcaption          trailingSub     │
└─────────────────────────────────────┘
```

### 4. SwiftUI Views

#### ExtensionRootView
**Location:** `CliqueMessages/Views/ExtensionRootView.swift`

Root view handling routing logic:
- Shows `NotAuthenticatedView` when not signed in
- Shows `CompactContentView` in compact mode
- Shows navigation-based content in expanded mode

#### CliqueListView
**Location:** `CliqueMessages/Views/CliqueListView.swift`

Displays user's cliques in a scrollable list:
- Clique thumbnail, name, member/flick counts
- Tap to navigate to collections
- Empty state when no cliques

#### CollectionListView
**Location:** `CliqueMessages/Views/CollectionListView.swift`

Displays collections within a selected clique:
- Collection cover image, name, flick count
- Visibility badge (Public/Private/Followers)
- Tap to navigate to flick grid

#### FlickGridView
**Location:** `CliqueMessages/Views/FlickGridView.swift`

3-column grid of flicks for selection:
- Thumbnail images with video/live photo indicators
- Tap to select and share via iMessage
- Loading and empty states

#### CreateCliqueView
**Location:** `CliqueMessages/Views/CreateCliqueView.swift`

Placeholder for creating cliques from extension:
- Currently shows "Coming soon" message
- Will create clique linked to current iMessage chat

### 5. Deep Link Handling

#### DeepLinkBuilder (in CliqueCore)
Generates URLs with `clique://` scheme:

```swift
// Flick: clique://flick/{flickId}?src=imessage
DeepLinkBuilder.flickURL(flickId: "abc123")

// Collection: clique://clique/{cliqueId}/collection/{collectionId}?src=imessage
DeepLinkBuilder.collectionURL(cliqueId: "xyz", collectionId: "abc")

// Clique: clique://clique/{cliqueId}?src=imessage
DeepLinkBuilder.cliqueURL(cliqueId: "xyz")
```

#### Main App Handlers
**Location:** `Clique/App/DeepLinks/`

| File | Purpose |
|------|---------|
| `FlickDeepLinkHandler.swift` | Handles `clique://flick/{id}` links |
| `CliqueDeepLinkHandler.swift` | Handles `clique://clique/{id}` links |
| `DeepLinkManager.swift` | Routes incoming URLs to appropriate handlers |

## Configuration Files

### Info.plist
**Location:** `CliqueMessages/Info.plist`

Key configurations:
- `NSExtension.NSExtensionPrincipalClass`: MessagesViewController
- `NSExtension.NSExtensionPointIdentifier`: com.apple.message-payload-provider

### Entitlements
**Location:** `CliqueMessages/CliqueMessages.entitlements`

Required entitlements:
- `com.apple.security.application-groups`: `group.com.cliquellc.clique`
- `keychain-access-groups`: `$(AppIdentifierPrefix)com.cliquellc.clique`

## Data Flow

### Cache Sync Flow (Main App → Extension)
```
1. User fetches cliques in main app
2. API returns [Clique] array
3. CacheSyncService.syncCliques() called
4. Converts to [CachedClique]
5. ExtensionCacheManager.saveCliques() writes JSON to App Group
6. Extension reads cached data on next launch
```

### Auth Token Flow
```
1. User signs in via Firebase in main app
2. AuthTokenSyncHelper receives auth state change
3. Gets Firebase ID token
4. SharedAuthStorage saves to Keychain (App Group)
5. Extension reads token via SharedAuthStorage.getAuthToken()
6. Extension can make authenticated API calls
```

### Chat Key Flow
```
1. Extension launches in iMessage conversation
2. MessagesViewController.willBecomeActive() called
3. Extract localParticipantIdentifier (current user UUID)
4. Extract remoteParticipantIdentifiers (other users UUIDs)
5. ChatKeyGenerator.generate() creates SHA256 hash
6. chatKey stored in ExtensionViewModel
7. Used to map iMessage chat → Clique group
```

### Message Sharing Flow
```
1. User browses cliques → collections → flicks
2. User taps a flick to share
3. MSMessageBuilder.buildFlickMessage() creates MSMessage
4. Layout shows thumbnail, metadata, deep link URL
5. User sends message in iMessage
6. Recipient taps bubble → opens main Clique app via deep link
7. DeepLinkManager routes to FlickDeepLinkHandler
8. App navigates to flick detail view
```

## Technical Decisions

### Why Local SPM Package?
- Code sharing between app and extension without CocoaPods complexity
- Clear separation of extension-safe code
- Easier to maintain platform availability checks

### Why Custom Image Loader?
- Kingfisher adds ~5MB and has features unnecessary for extension
- Extension has strict ~30MB memory limit
- Custom loader optimized for thumbnail loading
- Simpler cache management with automatic eviction

### Why JSON Caching?
- Simple, debuggable format
- No Core Data overhead for extension
- Fast read/write for small datasets
- Easy to clear and rebuild

### Why SHA256 for Chat Keys?
- Deterministic: same participants = same key
- Order-independent via sorting
- Collision-resistant
- Fast computation

## Build Verification

The extension builds successfully:
```
✅ iOS Simulator Build build succeeded for scheme CliqueMessages.
```

Warnings (non-blocking):
- AppIntents metadata extraction skipped (expected - no App Intents used)

## Future Enhancements

1. **API Integration** - Connect CreateCliqueView to backend API
2. **Flick Sync** - Add flick caching to CacheSyncService
3. **Offline Mode** - Full offline browsing with stale data indicators
4. **Message Replies** - Handle incoming message taps in extension
5. **Photo Upload** - Upload photos directly from extension
6. **Push Notifications** - Notify when clique content is shared

## File Summary

```
CliqueCore/
├── Package.swift
└── Sources/CliqueCore/
    ├── Models/
    │   ├── CachedClique.swift
    │   ├── CachedCollection.swift
    │   ├── CachedFlick.swift
    │   ├── CachedUser.swift
    │   └── Visibility.swift
    ├── Storage/
    │   ├── AppGroupManager.swift
    │   ├── SharedAuthStorage.swift
    │   ├── ChatKeyGenerator.swift
    │   ├── ChatKeyStore.swift
    │   └── ExtensionCacheManager.swift
    └── Utilities/
        ├── DeepLinkBuilder.swift
        └── ColorTheme.swift

CliqueMessages/
├── Info.plist
├── CliqueMessages.entitlements
├── MessagesViewController.swift
├── ViewModels/
│   └── ExtensionViewModel.swift
├── Views/
│   ├── ExtensionRootView.swift
│   ├── CliqueListView.swift
│   ├── CollectionListView.swift
│   ├── FlickGridView.swift
│   └── CreateCliqueView.swift
└── Utilities/
    ├── ExtensionImageLoader.swift
    ├── ExtensionAsyncImage.swift
    └── MSMessageBuilder.swift

Clique/Services/
├── CacheSyncService.swift
└── Helpers/
    └── AuthTokenSyncHelper.swift

Clique/App/DeepLinks/
├── FlickDeepLinkHandler.swift
├── CliqueDeepLinkHandler.swift
└── DeepLinkManager.swift (updated)
```
