//
//  ExtensionAsyncImage.swift
//  CliqueMessages
//
//  SwiftUI async image view for iMessage extension using ExtensionImageLoader.
//  Automatically cancels loading when view disappears to conserve memory.
//

import SwiftUI

// MARK: - Extension Async Image

/// A SwiftUI view that asynchronously loads and displays an image from a URL.
/// Uses ExtensionImageLoader for efficient caching and memory management.
///
/// Example usage:
/// ```swift
/// ExtensionAsyncImage(url: imageUrl) { phase in
///     switch phase {
///     case .loading:
///         ProgressView()
///     case .loaded(let image):
///         Image(uiImage: image)
///             .resizable()
///             .aspectRatio(contentMode: .fill)
///     case .failed:
///         Image(systemName: "photo")
///             .foregroundColor(.gray)
///     }
/// }
/// ```
public struct ExtensionAsyncImage<Content: View>: View {
    private let url: URL?
    private let content: (ImagePhase) -> Content

    @State private var phase: ImagePhase = .loading
    @State private var loadTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Create an async image view with custom phase content
    /// - Parameters:
    ///   - url: The URL of the image to load (optional)
    ///   - content: A view builder that creates content based on the loading phase
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (ImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        content(phase)
            .onAppear {
                // Always attempt to load if no task is running
                if loadTask == nil && url != nil {
                    loadImage()
                }
            }
            .onDisappear {
                // Cancel the task but let background loads complete and update cache
                // This prevents stuck loading states when quickly scrolling
                loadTask?.cancel()
                loadTask = nil
                // Note: We don't call ExtensionImageLoader.shared.cancelLoad() here
                // to allow the download to complete in background and populate the cache
            }
            .onChange(of: url) { _, newURL in
                // Cancel previous load and start new one when URL changes
                cancelLoad()
                if newURL != nil {
                    loadImage()
                }
            }
    }

    // MARK: - Private Methods

    private func loadImage() {
        print("ExtensionAsyncImage: loadImage() called for URL: \(url?.absoluteString.prefix(60) ?? "nil")")

        guard let url = url else {
            print("ExtensionAsyncImage: No URL provided")
            phase = .failed(nil)
            return
        }

        print("ExtensionAsyncImage: Starting load for \(url.absoluteString.prefix(60))...")
        phase = .loading

        loadTask = Task {
            do {
                let image = try await ExtensionImageLoader.shared.loadImage(from: url)

                // Check if task was cancelled
                guard !Task.isCancelled else {
                    print("ExtensionAsyncImage: Task cancelled for \(url.lastPathComponent)")
                    return
                }

                await MainActor.run {
                    print("ExtensionAsyncImage: Successfully loaded \(url.lastPathComponent)")
                    phase = .loaded(image)
                }
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    print("ExtensionAsyncImage: Task cancelled for \(url.lastPathComponent)")
                    return
                }

                await MainActor.run {
                    print("ExtensionAsyncImage: Failed to load \(url.lastPathComponent): \(error)")
                    phase = .failed(error)
                }
            }
        }
    }

    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil

        if let url = url {
            ExtensionImageLoader.shared.cancelLoad(for: url)
        }
    }
}

// MARK: - Default Content Extension

extension ExtensionAsyncImage where Content == AnyView {
    /// Create an async image view with default loading, loaded, and error states
    /// - Parameter url: The URL of the image to load
    public init(url: URL?) {
        self.init(url: url) { phase in
            AnyView(DefaultAsyncImageContent(phase: phase))
        }
    }
}

// MARK: - Default Content

/// Default content for ExtensionAsyncImage showing spinner, image, or error icon
struct DefaultAsyncImageContent: View {
    let phase: ImagePhase

    var body: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .failed:
            Image(systemName: "photo")
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Extension Thumbnail View Type

/// Defines different thumbnail display contexts for the iMessage extension.
/// Similar to CliquePfpViewType in the main app, this enum configures
/// size, corner radius, and styling for different use cases.
enum ExtensionThumbnailViewType {
    case cliqueRow      // Clique list row (56x56)
    case collectionRow  // Collection list row (60x60)

    var size: CGSize {
        switch self {
        case .cliqueRow:
            return CGSize(width: 56, height: 56)
        case .collectionRow:
            return CGSize(width: 60, height: 60)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .cliqueRow, .collectionRow:
            return 8
        }
    }

    var placeholderIcon: String {
        switch self {
        case .cliqueRow:
            return "person.3.fill"
        case .collectionRow:
            return "photo.stack"
        }
    }
}

// MARK: - Extension Thumbnail View

/// A reusable thumbnail view for displaying clique profile pictures or collection covers.
/// Uses ExtensionAsyncImage for efficient loading and applies consistent styling based on type.
struct ExtensionThumbnailView: View {
    let url: URL?
    let type: ExtensionThumbnailViewType

    /// Initialize with a URL
    init(url: URL?, type: ExtensionThumbnailViewType) {
        self.url = url
        self.type = type
    }

    /// Initialize with a URL string
    init(urlString: String, type: ExtensionThumbnailViewType) {
        self.url = URL(string: urlString)
        self.type = type
    }

    var body: some View {
        ExtensionAsyncImage(url: url) { phase in
            switch phase {
            case .loading:
                ProgressView()
            case .loaded(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: type.size.width, height: type.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: type.cornerRadius))
            case .failed:
                Image(systemName: type.placeholderIcon)
                    .font(.system(size: type.size.width * 0.35))
                    .foregroundStyle(Color.extensionSecondaryText.opacity(0.5))
            }
        }
        .frame(width: type.size.width, height: type.size.height)
        .background(
            RoundedRectangle(cornerRadius: type.cornerRadius)
                .fill(Color.extensionSecondaryBackground)
        )
    }
}

// MARK: - Preview Helper

#if DEBUG
struct ExtensionAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Default usage
            ExtensionAsyncImage(url: URL(string: "https://picsum.photos/200"))
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Custom phase handling
            ExtensionAsyncImage(url: URL(string: "https://picsum.photos/300")) { phase in
                switch phase {
                case .loading:
                    ProgressView()
                        .frame(width: 200, height: 200)
                case .loaded(let image):
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                case .failed(let error):
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        if let error = error {
                            Text(error.localizedDescription)
                                .font(.caption)
                        }
                    }
                    .frame(width: 200, height: 200)
                }
            }

            // Nil URL (shows error state)
            ExtensionAsyncImage(url: nil)
                .frame(width: 200, height: 200)
        }
        .padding()
    }
}

struct ExtensionThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack {
                    ExtensionThumbnailView(
                        url: URL(string: "https://picsum.photos/200"),
                        type: .cliqueRow
                    )
                    Text("Clique Row")
                        .font(.caption)
                }

                VStack {
                    ExtensionThumbnailView(
                        url: URL(string: "https://picsum.photos/201"),
                        type: .collectionRow
                    )
                    Text("Collection Row")
                        .font(.caption)
                }
            }

            HStack(spacing: 20) {
                VStack {
                    ExtensionThumbnailView(url: nil, type: .cliqueRow)
                    Text("Clique (no URL)")
                        .font(.caption)
                }

                VStack {
                    ExtensionThumbnailView(url: nil, type: .collectionRow)
                    Text("Collection (no URL)")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.extensionBackground)
    }
}
#endif
