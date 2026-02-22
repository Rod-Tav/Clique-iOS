//
//  SharedAlbumPickerSheet.swift
//  Clique
//
//  Sheet that lets users pick an iCloud Shared Album to link with a collection.
//

import SwiftUI
import Photos

@available(iOS 26, *)
struct SharedAlbumPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentToast) var presentToast
    @Environment(UserStore.self) var userStore

    let collectionId: String
    let collectionName: String
    @State var associationStore: SharedAlbumAssociationStore

    @State var albums: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []
    @State var isLoading: Bool = true
    @State var authorizationStatus: PHAuthorizationStatus = .notDetermined
    let imageManager = PHCachingImageManager()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .primaryBackground()
            .navigationTitle("Link Shared Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadAlbumsIfNeeded()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingGrid
        } else if albums.isEmpty {
            NoSharedAlbumGuidanceView()
                .padding(.top, 40)
        } else {
            albumGrid
            guidanceSection
        }
    }

    // MARK: - Album Grid

    private var albumGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(albums.indices, id: \.self) { index in
                let album = albums[index]
                let isLinked = associationStore.getAssociation(for: collectionId)?.sharedAlbumLocalIdentifier == album.collection.localIdentifier

                Button {
                    if isLinked {
                        unlinkAlbum()
                    } else {
                        selectAlbum(album)
                    }
                } label: {
                    albumCard(album, isLinked: isLinked)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    // MARK: - Album Card

    private func albumCard(_ album: (collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?), isLinked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let thumbnail = album.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipped()
                        .roundCorners(12)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                        Image(systemName: "photo.stack")
                            .font(.title2)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                    .frame(height: 160)
                    .roundCorners(12)
                }

                if isLinked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .green)
                        .padding(8)
                }
            }

            Text(album.title)
                .font(.subheadline.weight(.medium))
                .textPrimary()
                .lineLimit(1)

            HStack(spacing: 4) {
                Text("\(album.count)")
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)

                if isLinked {
                    Text("Linked")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .contentShape(.rect)
    }

    // MARK: - Loading Placeholders

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                albumPlaceholder
            }
        }
        .padding(16)
    }

    private var albumPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 160)
                .roundCorners(12)
                .shimmer()

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 80, height: 14)
                .roundCorners(4)

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 30, height: 12)
                .roundCorners(4)
        }
    }

    // MARK: - Guidance Section

    private var guidanceSection: some View {
        NoSharedAlbumGuidanceView()
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
    }
}
