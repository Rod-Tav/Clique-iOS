//
//  CloudCliqueSyncStatusView.swift
//  Clique
//

import SwiftUI

struct CloudCliqueSyncStatusView: View {
    let cliqueId: String
    @Environment(SyncedPhotoStore.self) var syncedPhotoStore

    var body: some View {
        let pendingCount = syncedPhotoStore.photosForClique(cliqueId)
            .filter { $0.syncState == .pending || $0.syncState == .syncing }
            .count

        if case .syncing = syncedPhotoStore.syncStatus {
            statusBanner(
                icon: "arrow.triangle.2.circlepath",
                text: pendingCount > 0 ? "Syncing \(pendingCount) photo\(pendingCount == 1 ? "" : "s")..." : "Syncing..."
            )
        } else if pendingCount > 0 {
            statusBanner(
                icon: "clock",
                text: "\(pendingCount) photo\(pendingCount == 1 ? "" : "s") pending sync"
            )
        } else if case .error(let message) = syncedPhotoStore.syncStatus {
            statusBanner(
                icon: "exclamationmark.triangle",
                text: message
            )
        }
    }

    private func statusBanner(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(Color.theme.textPrimary.opacity(0.7))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .maxWidth(.leading)
    }
}
