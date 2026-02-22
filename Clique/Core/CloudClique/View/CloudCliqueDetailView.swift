//
//  CloudCliqueDetailView.swift
//  Clique
//

import SwiftUI

struct CloudCliqueDetailView: View {
    let cliqueId: String
    let cliqueName: String

    @Environment(SyncedPhotoStore.self) var syncedPhotoStore
    @Environment(\.dismiss) var dismiss
    @State private var showAddPhotos = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            topBar
            CloudCliqueSyncStatusView(cliqueId: cliqueId)
            photoGrid
        }
        .primaryBackground()
        .sheet(isPresented: $showAddPhotos) {
            AddPhotoToCloudCliqueFlow(cliqueId: cliqueId)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.theme.iconPrimary)
            }
            .contentShape(.rect)

            Text(cliqueName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.theme.textPrimary)
                .maxWidth(.leading)

            Button {
                showAddPhotos = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.theme.iconPrimary)
            }
            .contentShape(.rect)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var photoGrid: some View {
        ScrollView {
            let photos = syncedPhotoStore.photosForClique(cliqueId)
            if photos.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photos) { photo in
                        photoCell(photo)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(Color.theme.iconPrimary.opacity(0.5))

            Text("No photos yet")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.theme.textPrimary.opacity(0.6))

            Text("Tap + to add photos from your library")
                .font(.footnote)
                .foregroundStyle(Color.theme.textPrimary.opacity(0.4))
        }
        .padding(.top, 80)
    }

    private func photoCell(_ photo: SyncedPhoto) -> some View {
        GeometryReader { geo in
            if let data = photo.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.theme.textPrimary.opacity(0.1))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
