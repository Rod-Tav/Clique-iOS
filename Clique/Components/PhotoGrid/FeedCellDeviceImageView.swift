//
//  FeedCellDeviceImageView.swift
//  Clique
//
//  Created by Assistant on feed cell device image fix.
//

import SwiftUI
import Photos

/// Global cache for device images to prevent flash when views are recreated
@MainActor
final class DeviceImageCache {
    static let shared = DeviceImageCache()

    private var cache: [String: UIImage] = [:]
    private var prefetchTasks: [String: Task<Void, Never>] = [:]
    private let maxCacheSize = 50  // Limit memory usage

    private init() {}

    func get(_ assetIdentifier: String) -> UIImage? {
        return cache[assetIdentifier]
    }

    func set(_ assetIdentifier: String, image: UIImage) {
        // Simple LRU: if cache is full, remove first item
        if cache.count >= maxCacheSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[assetIdentifier] = image
    }

    func clear() {
        cache.removeAll()
        // Cancel all prefetch tasks
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()
    }

    /// Prefetch images for PHAssets to avoid flash when user swipes to them
    func prefetch(assets: [PHAsset], width: CGFloat) {
        for asset in assets {
            // Skip if already cached
            guard cache[asset.localIdentifier] == nil else { continue }

            // Skip if already prefetching
            guard prefetchTasks[asset.localIdentifier] == nil else { continue }

            // Start prefetch task
            let task = Task {
                let options = PHImageRequestOptions()
                options.version = .current
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.resizeMode = .exact

                let scale = UIScreen.main.scale
                let targetSize = CGSize(width: width * scale * 2, height: width * scale * 2)

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: options
                    ) { image, info in
                        if let image = image {
                            Task { @MainActor in
                                self.set(asset.localIdentifier, image: image)
                                self.prefetchTasks.removeValue(forKey: asset.localIdentifier)
                                continuation.resume()
                            }
                        } else {
                            Task { @MainActor in
                                self.prefetchTasks.removeValue(forKey: asset.localIdentifier)
                                continuation.resume()
                            }
                        }
                    }
                }
            }

            prefetchTasks[asset.localIdentifier] = task
        }
    }
}

/// Specialized device image loader for feed cells that matches network image sizing exactly.
///
/// This component applies the same sizing chain that network images use in feed cells:
/// `.resizable() + .scaledToFill() + .aspectRatio(1, .fill) + .frame(width:) + .clipShape()`
///
/// This is different from `TwoStageImageLoader` which applies sizing at the container level.
/// Feed cells need sizing applied directly to each Image for correct square display.
///
/// ## Usage
/// ```swift
/// FeedCellDeviceImageView(
///     asset: phAsset,
///     width: UIScreen.width - 32
/// )
/// ```
struct FeedCellDeviceImageView: View {
    let asset: PHAsset
    let width: CGFloat

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    init(asset: PHAsset, width: CGFloat) {
        self.asset = asset
        self.width = width
    }

    var body: some View {
        Group {
            // Single-stage loading - match network image behavior
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.theme.iconTertiary
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .frame(width: width, height: width)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .id(asset.localIdentifier)  // Stable identity to prevent recreation during transitions
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancelRequest()
        }
    }

    private func loadImage() {
        // Check global cache first (instant, like Kingfisher)
        if let cachedImage = DeviceImageCache.shared.get(asset.localIdentifier) {
            self.image = cachedImage
            return
        }

        guard image == nil else { return }

        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .exact

        // Request high-quality square image (2x for retina)
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: width * scale * 2, height: width * scale * 2)

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            // Accept both final and degraded images for faster display
            if let image = image {
                DispatchQueue.main.async {
                    self.image = image
                    // Cache for future view recreations
                    DeviceImageCache.shared.set(self.asset.localIdentifier, image: image)
                }
            }
        }
    }

    private func cancelRequest() {
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
    }
}
