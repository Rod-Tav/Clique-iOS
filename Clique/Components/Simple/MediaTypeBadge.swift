//
//  MediaTypeBadge.swift
//  Clique
//
//  Created by Assistant on media type badge component.
//

import SwiftUI
import Photos

/// Reusable badge component for displaying media type indicators on photo thumbnails
struct MediaTypeBadge: View {
    let asset: PHAsset
    let style: BadgeStyle

    enum BadgeStyle {
        case grid    // Larger badges for photo grid cells
        case carousel // Smaller badges for carousel thumbnails

        var iconSize: CGFloat {
            switch self {
            case .grid: return 10
            case .carousel: return 6
            }
        }

        var livePhotoIconSize: CGFloat {
            switch self {
            case .grid: return 14
            case .carousel: return 8
            }
        }

        var textSize: CGFloat {
            switch self {
            case .grid: return 12
            case .carousel: return 8
            }
        }

        var spacing: CGFloat {
            switch self {
            case .grid: return 4
            case .carousel: return 2
            }
        }

        var padding: CGFloat {
            switch self {
            case .grid: return 6
            case .carousel: return 3
            }
        }
    }

    var body: some View {
        Group {
            if asset.isLivePhoto {
                livePhotoBadge
            } else if asset.isVideo {
                videoBadge
            }
        }
    }

    /// Video badge indicator (bottom-right corner with duration)
    private var videoBadge: some View {
        VStack {
            HStack(spacing: style.spacing) {
                Image(systemName: "play.fill")
                    .font(.system(size: style.iconSize, weight: .semibold))
                    .foregroundStyle(.white)

                if let duration = asset.formattedDuration {
                    Text(duration)
                        .font(.system(size: style.textSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .padding(style.padding)
            .maxWidth(.trailing)
        }
        .frameBottom()
    }

    /// Live Photo badge indicator (bottom-left corner)
    private var livePhotoBadge: some View {
        VStack {
            HStack {
                Image(systemName: "livephoto")
                    .font(.system(size: style.livePhotoIconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(style.padding)
            }
            .maxWidth(.leading)
        }
        .frameBottom()
    }
}
