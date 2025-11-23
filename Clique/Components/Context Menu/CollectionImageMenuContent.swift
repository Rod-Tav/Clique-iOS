//
//  CollectionImageMenuContent.swift
//  Clique
//
//  Created by Assistant for shared collection image context menu.
//

import SwiftUI
import Toasts

/// Reusable menu content for collection images
/// Used by CollectionDetailView and CollectionMainView to provide consistent menu actions
struct CollectionImageMenuContent: View {
    let image: CollectionImage
    let collectionId: String

    @Binding var showDeleteAlert: Bool
    @Binding var showReportCover: Bool

    @Environment(\.presentToast) private var presentToast
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore

    private var cid: String? {
        collectionStore.collections[collectionId]?.cliqueId
    }

    private var isUserInClique: Bool {
        guard let cid else { return false }
        return isInClique(cid: cid, cliqueStore)
    }

    var body: some View {
        // MEMBER-ONLY ACTIONS (requires user to be in the clique)
        if isUserInClique {
            // Share action
            if let highQualityUrl = image.imageUrl?.highQualityUrl,
               let url = URL(string: highQualityUrl) {
                ShareLink(item: url) {
                    Text("Share")
                    Image("share")
                        .color(.theme.iconPrimary)
                }
            }

            // Save button (conditional based on media type)
            if image.isLivePhoto {
                Button {
                    Task {
                        await CollectionImageSaveHelpers.saveLivePhoto(
                            image: image,
                            collectionImageStore: collectionImageStore,
                            presentToast: { toast in presentToast(toast) }
                        )
                    }
                } label: {
                    Text("Save Live Photo")
                    Image("download")
                        .color(.theme.iconPrimary)
                }
            } else if image.isVideo {
                Button {
                    Task {
                        await CollectionImageSaveHelpers.saveVideo(
                            image: image,
                            presentToast: { toast in presentToast(toast) }
                        )
                    }
                } label: {
                    Text("Save Video")
                    Image("download")
                        .color(.theme.iconPrimary)
                }
            } else {
                Button {
                    Task {
                        await CollectionImageSaveHelpers.saveImage(
                            image: image,
                            presentToast: { toast in presentToast(toast) }
                        )
                    }
                } label: {
                    Text("Save Image")
                    Image("download")
                        .color(.theme.iconPrimary)
                }
            }

            DeleteButton {
                showDeleteAlert = true
            }
        }

        // ALWAYS AVAILABLE
        ReportButton {
            showReportCover = true
        }
    }
}
