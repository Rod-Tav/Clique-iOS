//
//  CollectionImageContextMenuHandlers.swift
//  Clique
//
//  Reusable view modifier for handling collection image context menu actions.
//

import SwiftUI
import Toasts

/// View modifier that handles presentation of context menu actions for collection images.
/// Use this with `CollectionImageMenuContent` to provide consistent context menu behavior.
struct CollectionImageContextMenuHandlers: ViewModifier {
    @Binding var deleteAlertImage: CollectionImage?
    @Binding var reportImage: CollectionImage?
    @Binding var shareItem: ShareItem?
    @Binding var showSharePreparation: Bool

    let onDelete: (CollectionImage) async -> Void

    @Environment(\.presentToast) private var presentToast

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: Binding(
                get: { reportImage != nil },
                set: { if !$0 { reportImage = nil } }
            )) {
                if let reportImage {
                    ReportView(showReport: .constant(true), objectId: reportImage.id, reportType: .image)
                }
            }
            .alert(
                "Are you sure you want to delete this flick?",
                isPresented: Binding(
                    get: { deleteAlertImage != nil },
                    set: { if !$0 { deleteAlertImage = nil } }
                ),
                presenting: deleteAlertImage
            ) { image in
                Button("Delete", role: .destructive) {
                    Task {
                        await onDelete(image)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This action cannot be undone.")
            }
            .shareSheet(item: $shareItem)
            .overlay {
                if showSharePreparation {
                    ProcessingOverlay(message: "Preparing to share...")
                }
            }
    }
}

extension View {
    /// Adds handlers for collection image context menu actions.
    /// - Parameters:
    ///   - deleteAlertImage: Binding to the image being deleted (nil when no delete in progress)
    ///   - reportImage: Binding to the image being reported (nil when no report in progress)
    ///   - shareItem: Binding to the item being shared
    ///   - showSharePreparation: Binding to show/hide the share preparation overlay
    ///   - onDelete: Async closure called when delete is confirmed
    func collectionImageContextMenuHandlers(
        deleteAlertImage: Binding<CollectionImage?>,
        reportImage: Binding<CollectionImage?>,
        shareItem: Binding<ShareItem?>,
        showSharePreparation: Binding<Bool>,
        onDelete: @escaping (CollectionImage) async -> Void
    ) -> some View {
        modifier(CollectionImageContextMenuHandlers(
            deleteAlertImage: deleteAlertImage,
            reportImage: reportImage,
            shareItem: shareItem,
            showSharePreparation: showSharePreparation,
            onDelete: onDelete
        ))
    }
}
