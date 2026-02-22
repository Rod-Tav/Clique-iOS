//
//  RecentPhotoCell.swift
//  Clique
//
//  Individual thumbnail cell for the Recent Photos carousel.
//

import SwiftUI
import Photos

/// A compact photo thumbnail cell for the Recent Photos carousel.
///
/// Displays a 100x100pt thumbnail with selection overlay matching the app's
/// existing selection pattern (blue circle + white checkmark).
struct RecentPhotoCell: View {
    /// The photo asset to display
    let asset: PHAsset
    /// Whether this photo is currently selected
    let isSelected: Bool
    /// Cached thumbnail image if available
    let thumbnail: UIImage?
    /// Tap action callback
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                } else {
                    placeholder
                }

                if isSelected {
                    selectionOverlay
                }
            }
            .frame(width: 100, height: 100)
            .roundCorners(8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Gray placeholder with a small spinner while thumbnail loads
    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 100, height: 100)
            .overlay(
                ProgressView()
                    .scaleEffect(0.5)
            )
    }

    /// Blue checkmark overlay for selected photos — matches PhotoGridCell pattern
    private var selectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)

            VStack {
                HStack {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(4)
                }

                Spacer()
            }
        }
        .animation(.snappy(duration: 0.25, extraBounce: 0), value: isSelected)
    }
}
