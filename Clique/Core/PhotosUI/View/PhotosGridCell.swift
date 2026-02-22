//
//  PhotosGridCell.swift
//  Clique
//
//  Lightweight display-only thumbnail cell for the photos grid.
//

import SwiftUI

struct PhotosGridCell: View {
    var thumbnail: UIImage?

    var body: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 120)
        }
    }
}

/// Tappable variant that hooks into the hero animation system
struct TappablePhotosGridCell: View {
    var thumbnail: UIImage?
    var identifier: String
    var onTap: () -> Void

    var body: some View {
        PhotosGridCell(thumbnail: thumbnail)
            .heroSourceLocal(identifier: identifier, image: thumbnail, action: onTap)
    }
}
