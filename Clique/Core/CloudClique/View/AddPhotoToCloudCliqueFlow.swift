//
//  AddPhotoToCloudCliqueFlow.swift
//  Clique
//

import SwiftUI
import PhotosUI

struct AddPhotoToCloudCliqueFlow: View {
    let cliqueId: String
    @Environment(\.dismiss) var dismiss
    @Environment(SyncedPhotoStore.self) var syncedPhotoStore
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    ProgressView("Processing photos...")
                        .foregroundStyle(Color.theme.textPrimary)
                } else {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.theme.iconPrimary)

                            Text("Select Photos")
                                .font(.headline)
                                .foregroundStyle(Color.theme.textPrimary)

                            Text("Choose photos to add to this clique")
                                .font(.subheadline)
                                .foregroundStyle(Color.theme.textPrimary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .primaryBackground()
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await processSelectedPhotos(items) }
            }
        }
    }

    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isProcessing = true }

        let syncDB = SyncedDatabase()

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }

            let thumbnailData = ThumbnailGenerator.generate(from: uiImage)

            let photo = SyncedPhoto(
                id: UUID().uuidString,
                cliqueId: cliqueId,
                ownerUserId: SharedAuthState.load()?.userId ?? "",
                ownerUsername: SharedAuthState.load()?.username ?? "",
                thumbnailData: thumbnailData,
                mediaType: "PHOTO",
                captureDate: Date(),
                userModificationDate: Date(),
                syncState: .pending
            )

            await syncDB.enqueuePhoto(photo)
            await MainActor.run {
                syncedPhotoStore.updatePhoto(photo)
            }
        }

        await MainActor.run {
            isProcessing = false
            dismiss()
        }
    }
}
