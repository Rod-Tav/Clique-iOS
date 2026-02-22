//
//  FlickGridView.swift
//  CliqueMessages
//
//  Displays a grid of flicks for sharing via iMessage
//

import SwiftUI


struct FlickGridView: View {
    let viewModel: ExtensionViewModel
    let onFlickSelected: (CachedFlick) -> Void

    /// Maximum number of flicks cached per collection
    private let maxCachedFlicks = 50

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    /// Whether there are more flicks available in the main app
    private var hasMoreFlicks: Bool {
        guard let collection = viewModel.selectedCollection else { return false }
        return viewModel.flicks.count >= maxCachedFlicks && collection.flickCount > maxCachedFlicks
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                if viewModel.isLoading {
                    loadingState
                } else if viewModel.flicks.isEmpty {
                    emptyState
                } else {
                    flickGrid
                }
            }
            .background(Color(.systemBackground))
            .disabled(viewModel.isSendingFlick)
            .opacity(viewModel.isSendingFlick ? 0.5 : 1)

            // Sending overlay
            if viewModel.isSendingFlick {
                sendingOverlay
            }
        }
    }

    // MARK: - Sending Overlay

    private var sendingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Sending...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(width: 140, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Back button
            Button {
                viewModel.navigateBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.cliquePink)
            }
            .padding(.leading, 16)

            Spacer()

            VStack(spacing: 4) {
                Text("Select a Flick to Share")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let collection = viewModel.selectedCollection {
                    Text("\(viewModel.flicks.count) flick\(viewModel.flicks.count == 1 ? "" : "s") from \(collection.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Spacer for symmetry
            Color.clear
                .frame(width: 40)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Flick Grid

    private var flickGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(viewModel.flicks) { flick in
                        flickCell(flick)
                            .contentShape(.rect)
                            .onTapGesture {
                                onFlickSelected(flick)
                            }
                    }
                }
                .padding(2)

                // Show "View More in App" button when there are more flicks
                if hasMoreFlicks {
                    viewMoreInAppButton
                }
            }
        }
    }

    // MARK: - View More in App Button

    private var viewMoreInAppButton: some View {
        Button {
            openCollectionInApp()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("View More in App")
                        .font(.subheadline.weight(.semibold))

                    if let collection = viewModel.selectedCollection {
                        Text("\(collection.flickCount - viewModel.flicks.count) more flicks available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.cliquePink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cliquePink.opacity(0.1))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    /// Opens the collection in the main Clique app
    private func openCollectionInApp() {
        guard let clique = viewModel.selectedClique,
              let collection = viewModel.selectedCollection else {
            return
        }

        let deepLinkURL = DeepLinkBuilder.collectionURL(
            cliqueId: clique.id,
            collectionId: collection.id
        )

        viewModel.openURLHandler?(deepLinkURL)
    }

    private func flickCell(_ flick: CachedFlick) -> some View {
        let _ = print("FlickGridView: Rendering flick \(flick.id), thumbUrl: \(flick.thumbUrl.prefix(60))...")

        return GeometryReader { geometry in
            Group {
                if let url = URL(string: flick.thumbUrl) {
                    ExtensionAsyncImage(url: url) { phase in
                        switch phase {
                        case .loading:
                            ProgressView()
                                .frame(width: geometry.size.width, height: geometry.size.width)
                        case .loaded(let image):
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.width)
                                .clipped()
                        case .failed:
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                                .frame(width: geometry.size.width, height: geometry.size.width)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .overlay(alignment: .bottomTrailing) {
                        if flick.mediaType == .VIDEO {
                            videoIndicator
                        } else if flick.mediaType == .LIVE {
                            livePhotoIndicator
                        }
                    }
                } else {
                    // Fallback placeholder for invalid URL
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Media Type Indicators

    private var videoIndicator: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(6)
            .background(
                Circle()
                    .fill(.black.opacity(0.5))
            )
            .padding(6)
    }

    private var livePhotoIndicator: some View {
        Image(systemName: "livephoto")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.black.opacity(0.5))
            )
            .padding(6)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading flicks...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Flicks")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("This collection doesn't have any flicks yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
