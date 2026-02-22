//
//  BatchExportSheet.swift
//  Clique
//
//  Sheet that exports all collection flicks to a local Photos album.
//

import SwiftUI
import Toasts

@available(iOS 26, *)
struct BatchExportSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentToast) var presentToast

    let collection: ClCollection
    @State var exportHelper = BatchExportHelper()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                collectionSummary

                if exportHelper.isExporting {
                    exportProgressView
                } else if exportHelper.exportProgress >= 1.0 {
                    completionView
                } else {
                    exportButton
                }

                Spacer()
            }
            .padding(24)
            .primaryBackground()
            .navigationTitle("Export to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var collectionSummary: some View {
        VStack(spacing: 8) {
            Text(collection.name)
                .font(.headline)
                .textPrimary()

            Text(mediaSummaryText)
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var exportButton: some View {
        CliqueButton(
            type: .primary,
            text: "Export to \(collection.name)",
            fullWidth: true,
            action: {
                Task {
                    await exportHelper.exportCollection(collection.images, albumName: collection.name)
                    if exportHelper.error == nil {
                        presentToast(Toasts.exportComplete)
                    } else {
                        presentToast(Toasts.exportFailed)
                    }
                }
            }
        )
    }

    private var exportProgressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: exportHelper.exportProgress)
                .tint(Color.theme.buttonCTA)

            Text("\(exportHelper.exportedCount) of \(exportHelper.totalCount)")
                .font(.caption)
                .foregroundStyle(Color.theme.textSecondary)
        }
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.theme.buttonCTA)

            if let error = exportHelper.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Exported \(exportHelper.exportedCount) items to \"\(collection.name)\"")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private var mediaSummaryText: String {
        let counts = collection.mediaTypeCounts
        var parts: [String] = []
        if counts.photos > 0 {
            parts.append("\(counts.photos) \(counts.photos == 1 ? "photo" : "photos")")
        }
        if counts.livePhotos > 0 {
            parts.append("\(counts.livePhotos) \(counts.livePhotos == 1 ? "Live Photo" : "Live Photos")")
        }
        if counts.videos > 0 {
            parts.append("\(counts.videos) \(counts.videos == 1 ? "video" : "videos")")
        }
        return parts.isEmpty ? "No items" : parts.joined(separator: ", ")
    }
}
