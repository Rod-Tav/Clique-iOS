//
//  PhotoGridCell.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI
import Photos

/// Individual photo cell in the grid with selection state visualization.
struct PhotoGridCell: View {
    /// The photo asset to display
    let asset: PHAsset
    /// Whether this photo is currently selected
    let isSelected: Bool
    /// Cached thumbnail image if available
    let thumbnail: UIImage?
    /// Whether this photo is being removed during drag selection
    var isBeingRemoved: Bool = false
    /// Tap action callback
    let action: () -> Void

    /// Whether this asset is a Live Photo
    private var isLivePhoto: Bool {
        asset.mediaSubtypes.contains(.photoLive)
    }

    /// Whether this asset is a video
    private var isVideo: Bool {
        asset.mediaType == .video
    }

    /// Video duration formatted as string (e.g., "1:23")
    private var videoDuration: String? {
        guard isVideo else { return nil }
        let duration = Int(asset.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Calculated cell size for 3-column grid
    private var cellSize: CGFloat {
        (UIScreen.width - 4) / 3
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(cellSize)
                        .clipped()
                } else {
                    loadingView
                }

                // Media type badges
                if isLivePhoto {
                    livePhotoBadge
                } else if isVideo {
                    videoBadge
                }

                if isSelected && !isBeingRemoved {
                    selectionOverlay
                } else if isBeingRemoved {
                    removalOverlay
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
    
    /// Loading placeholder while thumbnail loads
    private var loadingView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(cellSize)
            .overlay(
                ProgressView()
                    .scaleEffect(0.5)
            )
    }
    
    
    /// Blue checkmark overlay for selected photos
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
    
    /// Red minus overlay for photos being removed during drag
    private var removalOverlay: some View {
        ZStack {
            Color.red.opacity(0.4)

            VStack {
                HStack {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 24, height: 24)

                        Image(systemName: "minus")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(4)
                }

                Spacer()
            }
        }
        .animation(.snappy(duration: 0.25, extraBounce: 0), value: isBeingRemoved)
    }

    /// Live Photo badge indicator (bottom-left corner)
    private var livePhotoBadge: some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: "livephoto")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(6)

                Spacer()
            }
        }
    }

    /// Video badge indicator (bottom-right corner with duration)
    private var videoBadge: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)

                    if let duration = videoDuration {
                        Text(duration)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .padding(6)
            }
        }
    }
}
