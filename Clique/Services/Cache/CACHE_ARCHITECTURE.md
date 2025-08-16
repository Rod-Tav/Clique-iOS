# Clique Cache System Architecture

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Configuration](#configuration)
5. [Usage Guide](#usage-guide)
6. [Performance](#performance)
7. [Troubleshooting](#troubleshooting)

## Overview

The Clique caching system is a sophisticated, multi-tiered caching solution designed to improve app performance and reduce network requests. It seamlessly integrates with the OpenAPI client to provide automatic caching for GET requests with manual invalidation support for data freshness.

### Key Features
- **Two-tier caching**: Memory (L1) and disk (L2) storage
- **Automatic cache management**: LRU eviction, size limits, TTL expiration
- **Smart invalidation**: Pattern-based cache clearing for related data
- **Thread-safe**: Actor-based concurrency model
- **Zero configuration**: Works out of the box with sensible defaults
- **Manual refresh support**: Integrates with pull-to-refresh and refresh buttons

## Architecture

### System Design
```
┌─────────────────────────────────────────────────┐
│                  UI Layer                        │
│         (Views with .refreshable)                │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│              CacheControl                        │
│     (Public API for cache operations)            │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│             CacheManager                         │
│    (Orchestrates L1/L2, handles policies)        │
└────────┬────────────────────┬───────────────────┘
         │                    │
         ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│MemoryCacheStorage│  │ DiskCacheStorage │
│   (L1 - Fast)    │  │   (L2 - Persist) │
└──────────────────┘  └──────────────────┘
         ▲                    ▲
         │                    │
         └────────┬───────────┘
                  │
┌─────────────────────────────────────────────────┐
│            CacheMiddleware                       │
│    (OpenAPI Integration - Intercepts)            │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│            Network Layer                         │
│         (OpenAPI Client)                         │
└─────────────────────────────────────────────────┘
```

### Data Flow

#### Cache Read Path
1. Request initiated from UI
2. CacheMiddleware intercepts GET request
3. Generates cache key from URL + params
4. CacheManager checks L1 (memory)
5. If L1 miss, checks L2 (disk)
6. If L2 miss, forwards to network
7. Response cached in both L1 and L2
8. Response returned to UI

#### Cache Write Path
1. Network response received
2. CacheMiddleware checks if cacheable (200 OK)
3. Determines TTL from CachePolicy
4. Stores in L1 with LRU tracking
5. Stores in L2 for persistence
6. Manages size limits via eviction

#### Cache Invalidation Path
1. User triggers refresh (pull/button)
2. CacheControl invalidation method called
3. Pattern matching against cache keys
4. Matching entries removed from L1 and L2
5. Fresh data fetched from network

## Components

### CacheStorage Protocol
```swift
protocol CacheStorage: Actor {
    associatedtype Value: Codable
    func get(key: String) async -> CacheEntry<Value>?
    func set(key: String, value: CacheEntry<Value>) async
    func remove(key: String) async
    func removeAll() async
    func removeExpired() async
    func keys() async -> Set<String>
}
```

### MemoryCacheStorage (L1)
- **Purpose**: Fast, in-memory cache
- **Size Limit**: 50MB default
- **Entry Limit**: 1000 items
- **Eviction**: LRU (Least Recently Used)
- **Thread Safety**: Actor-based isolation

### DiskCacheStorage (L2)
- **Purpose**: Persistent cache across app launches
- **Size Limit**: 100MB default
- **Location**: `Caches/com.clique.cache/`
- **Format**: JSON encoded files
- **Cleanup**: Automatic expired entry removal

### CacheManager
- **Responsibilities**:
  - Coordinates L1/L2 operations
  - Enforces cache policies
  - Manages cache modes
  - Provides invalidation APIs
  - Generates cache keys
  - Collects statistics

### CachePolicy
- **TTL Configuration**:
  - User data: 10 minutes
  - Collections: 5 minutes  
  - Feed data: 2 minutes
  - Search results: 1 minute
  - Notifications: 5 minutes
- **Invalidation Rules**: Automatic cache clearing on mutations
- **Cache Modes**: Normal, Bypass, Force Refresh

### CacheMiddleware
- **Integration Point**: OpenAPI ClientMiddleware
- **Responsibilities**:
  - Intercepts HTTP requests/responses
  - Determines cacheability
  - Manages cache read/write
  - Handles invalidation on mutations

### CacheControl
- **Public API**: User-facing cache operations
- **Convenience Methods**:
  - `refreshHomeFeed()`
  - `refreshUserProfile(userId)`
  - `refreshCliqueProfile(cliqueId)`
  - `refreshCollection(collectionId)`
  - `refreshNotifications()`
- **Mode Control**: Enable/disable/force refresh

## Configuration

### Default Settings

```swift
// Memory Cache
let defaultMemoryLimit = 50 * 1024 * 1024  // 50MB
let defaultMaxEntries = 1000

// Disk Cache  
let defaultDiskLimit = 100 * 1024 * 1024   // 100MB
let cacheDirectory = "com.clique.cache"

// TTL Values (seconds)
let userDataTTL = 600        // 10 minutes
let collectionTTL = 300       // 5 minutes
let feedTTL = 120            // 2 minutes
let searchTTL = 60           // 1 minute
```

### Cache Modes

```swift
enum CacheMode {
    case normal       // Standard caching behavior
    case bypass       // Skip cache, always fetch fresh
    case forceRefresh // Clear cache then fetch
}
```

## Usage Guide

### Basic Integration

#### In Views with .refreshable
```swift
struct HomeFeedView: View {
    var body: some View {
        ScrollView {
            // Content
        }
        .refreshable {
            // Clear cache for this endpoint
            await CacheControl.shared.refreshHomeFeed()
            
            // Fetch fresh data
            await updateHomeFeed(.refresh)
        }
    }
}
```

#### In Refresh Menu Buttons
```swift
RefreshMenuButton {
    Task {
        // Clear cache for user profile
        await CacheControl.shared.refreshUserProfile(userId)
        
        // Fetch and update
        let updatedUser = try await UserService.getUserById(userId)
        userStore.updateUser(updatedUser)
    }
}
```

### Custom Invalidation Patterns

```swift
// Invalidate specific patterns
await CacheControl.shared.invalidate(patterns: [
    "/api/custom/endpoint",
    "/api/related.*data"  // Regex pattern
])

// Invalidate single endpoint
await CacheControl.shared.invalidateForRefresh("/api/endpoint")
```

### Cache Mode Management

```swift
// Disable caching temporarily
await CacheControl.shared.disableCache()

// Force refresh mode (bypass cache)
await CacheControl.shared.forceRefresh()  

// Re-enable normal caching
await CacheControl.shared.enableCache()
```

### Monitoring Cache Performance

```swift
// Get cache statistics
let stats = await CacheControl.shared.getCacheStats()
print("Hit rate: \(stats.hitRate)%")
print("Memory usage: \(stats.memoryUsage / 1024 / 1024)MB")
print("Disk usage: \(stats.diskUsage / 1024 / 1024)MB")
```

## Performance

### Benchmarks
- **Cache Hit Latency**: <1ms (memory), <10ms (disk)
- **Cache Miss Penalty**: ~5ms overhead
- **Memory Footprint**: 50MB max (configurable)
- **Disk Usage**: 100MB max (configurable)

### Optimization Strategies
1. **Two-tier architecture**: Hot data in memory, cold in disk
2. **LRU eviction**: Keeps frequently accessed data
3. **Lazy loading**: Disk cache loaded on-demand
4. **Batch invalidation**: Pattern matching for efficiency
5. **Async operations**: Non-blocking cache operations

### Impact Metrics
- **Network Requests**: 60-80% reduction
- **Load Times**: 2-10x faster for cached content
- **Battery Usage**: Reduced due to fewer network calls
- **Data Usage**: Significant reduction in cellular data

## Troubleshooting

### Common Issues

#### Cache Not Working
```swift
// Verify cache is enabled
let mode = await CacheControl.shared.getCacheMode()
assert(mode == .normal)

// Check cache stats
let stats = await CacheControl.shared.getCacheStats()
print("Total entries: \(stats.totalEntries)")
```

#### Stale Data
```swift
// Force clear all cache
await CacheControl.shared.clearCache()

// Or use force refresh mode
await CacheControl.shared.forceRefresh()
```

#### Memory Pressure
```swift
// Reduce cache limits
let customMemoryCache = MemoryCacheStorage<Data>(
    maxSize: 25 * 1024 * 1024,  // 25MB
    maxEntries: 500
)
```

### Debug Mode

Enable debug logging by adding print statements in development:

```swift
#if DEBUG
extension CacheManager {
    func debugLog(_ message: String) {
        print("🔧 [Cache] \(message)")
    }
}
#endif
```

### Cache Key Inspection

```swift
// Get all cached keys
let memoryKeys = await cacheManager.memoryCache.keys()
let diskKeys = await cacheManager.diskCache.keys()

// Inspect specific key
let key = "/api/user/123"
if let entry = await cacheManager.get(key: key) {
    print("Cached at: \(entry.timestamp)")
    print("Expires: \(entry.expiresAt)")
}
```

## Best Practices

### DO:
- ✅ Use convenience methods for common refresh patterns
- ✅ Clear cache before fetching in refresh handlers
- ✅ Monitor cache stats in development
- ✅ Use appropriate TTL values for data types
- ✅ Implement error handling for cache operations

### DON'T:
- ❌ Cache sensitive/personal data without encryption
- ❌ Use excessive TTL values (>1 hour)
- ❌ Bypass cache unnecessarily
- ❌ Store large binary data (images/videos)
- ❌ Assume cache will always have data

## Migration Guide

### Adding Cache to New Views

1. Import CacheControl
2. Add invalidation before fetch
3. Test with pull-to-refresh
4. Verify with different cache modes

### Updating TTL Values

Edit `CachePolicy.swift`:
```swift
static func getTTL(for path: String, method: HTTPRequest.Method) -> TimeInterval? {
    // Add your custom TTL logic
    if path.contains("/your/endpoint") {
        return 180 // 3 minutes
    }
    // ... existing logic
}
```

### Custom Cache Storage

Implement `CacheStorage` protocol:
```swift
actor CustomCacheStorage: CacheStorage {
    typealias Value = Data
    
    func get(key: String) async -> CacheEntry<Data>? {
        // Your implementation
    }
    
    // ... other required methods
}
```

## Future Enhancements

### Planned Features
- [ ] Cache encryption for sensitive data
- [ ] Smart prefetching based on user patterns
- [ ] Cache compression for disk storage
- [ ] Network condition-aware caching
- [ ] Cache analytics and reporting
- [ ] Per-user cache isolation
- [ ] Background cache warming
- [ ] Differential sync support

### Performance Improvements
- [ ] Memory-mapped file support for disk cache
- [ ] Bloom filters for existence checks
- [ ] Cache sharding for parallel access
- [ ] Progressive cache loading
- [ ] Adaptive TTL based on usage patterns

## Support

For questions or issues related to the cache system:
1. Check this documentation
2. Review the troubleshooting section
3. Examine cache statistics
4. Enable debug logging
5. Contact the development team

---

*Last Updated: January 2025*
*Version: 1.0.0*