//
//  GridAsyncImage.swift
//  Clique
//
//  Created by Assistant on 3/19/25.
//
// Lightweight image component optimized for grid views.
// Unlike GenericAsyncImage, this uses a single layer with no animations
// and performs all operations asynchronously to prevent UI blocking.

import SwiftUI
import Kingfisher

/// Tracks concurrent image loads to prevent overwhelming the system
@MainActor
final class GridImageLoadThrottler: ObservableObject {
    static let shared = GridImageLoadThrottler()

    private var activeLoads: Set<String> = []
    private let maxConcurrentLoads = 6
    private var pendingLoads: [(String, () -> Void)] = []

    private init() {}

    func requestLoad(for url: String, load: @escaping () -> Void) {
        if activeLoads.count < maxConcurrentLoads {
            activeLoads.insert(url)
            load()
        } else {
            pendingLoads.append((url, load))
        }
    }

    func loadCompleted(for url: String) {
        activeLoads.remove(url)

        // Start next pending load if any
        if !pendingLoads.isEmpty {
            let next = pendingLoads.removeFirst()
            activeLoads.insert(next.0)
            next.1()
        }
    }

    func cancelLoad(for url: String) {
        activeLoads.remove(url)
        pendingLoads.removeAll { $0.0 == url }
    }
}

/// Lightweight async image view optimized for grid layouts
struct GridAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (KFImage) -> Content
    let placeholder: () -> Placeholder

    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var loadTask: Task<Void, Never>?

    private let throttler = GridImageLoadThrottler.shared
    private let imageId = UUID().uuidString.prefix(8)

    init(
        url: String?,
        @ViewBuilder content: @escaping (KFImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let url = url, (hasLoaded || isLoading) {
                // Show the image (either cached or loading)
                content(
                    KFImage(URL(string: url))
                        .resizable()
                        .fade(duration: 0) // No fade animation
                        .forceTransition(false) // Disable transitions
                        .onSuccess { _ in
                            // Set hasLoaded when download completes successfully
                            if !hasLoaded {
                                hasLoaded = true
                                isLoading = false
                            }
                        }
                        .onFailure { _ in
                            // Reset loading state on failure
                            isLoading = false
                            hasLoaded = false
                        }
                )
            } else {
                // Show placeholder before loading starts or if no URL
                placeholder()
            }
        }
        .onAppear {
            startLoadingIfNeeded()
        }
        .onDisappear {
            cancelLoading()
        }
    }

    private func startLoadingIfNeeded() {
        guard let url = url, !hasLoaded, !isLoading else { return }

        isLoading = true

        // Use throttler to limit concurrent loads
        throttler.requestLoad(for: url) { [url] in
            loadTask = Task {
                await checkCacheAndLoad(url: url)
            }
        }
    }

    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil

        if let url = url {
            throttler.cancelLoad(for: url)
        }
    }

    @MainActor
    private func checkCacheAndLoad(url urlString: String) async {
        // Check cache asynchronously
        guard let url = URL(string: urlString) else { return }

        let resource = KF.ImageResource(downloadURL: url)
        let cache = KingfisherManager.shared.cache

        // Perform cache check on background thread
        let isCached = await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let cached = cache.isCached(forKey: resource.cacheKey)
                continuation.resume(returning: cached)
            }
        }

        if isCached {
            // Image is cached, can display immediately
            hasLoaded = true
            isLoading = false
        } else {
            // Need to download - keep loading state and let KFImage handle it
            // hasLoaded will be set after download completes
            isLoading = true
        }

        throttler.loadCompleted(for: urlString)
    }
}

/// Convenience wrapper for collection preview images in grids
/// Now uses GenericAsyncImage with performanceMode for consistency
struct GridCollectionPreviewImage: View {
    let urls: PhotoUrls?

    var body: some View {
        GenericAsyncImage(urls: urls, quality: .medium, shouldFixSize: false, performanceMode: true) { image in
            image
                .contentConfigure { img in
                    img.collectionPreviewImageModifiers()
                }
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(Constants.collectionPreviewRatio, contentMode: .fill)
        }
    }
}
