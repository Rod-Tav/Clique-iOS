//
//  DateMediaTypeLabel.swift
//  Clique
//
//  Created by Assistant on Date and media type label implementation.
//

import SwiftUI

/// Displays date, time, and media type indicator (Live Photo or Video) inline.
///
/// Shows format: "Date • Time • [icon] LIVE/duration"
/// - Regular photos: "January 15, 2025 • 2:30 PM"
/// - Live Photos: "January 15, 2025 • 2:30 PM • ● LIVE"
/// - Videos: "January 15, 2025 • 2:30 PM • ▶ 1:23"
///
/// ## Usage
/// ```swift
/// DateMediaTypeLabel(
///     image: collectionImage,
///     dateFormat: .full,  // or .short
///     fontSize: .caption,  // or .caption2
///     compact: gridColumns >= 4  // Use compact mode for narrow spaces
/// )
/// ```
///
/// **Compact mode**: Reduces font size and spacing for video info to fit in narrow layouts (e.g., 4-column grids)
struct DateMediaTypeLabel: View {
    @Environment(CollectionImageStore.self) private var collectionImageStore

    let image: CollectionImage
    let dateFormat: DateFormat
    let fontSize: FontSize
    let textColor: Color

    @State private var fetchedDuration: TimeInterval?
    @State private var timezoneOffset: String?

    private var displayDuration: TimeInterval? {
        image.videoDuration ?? fetchedDuration
    }

    init(image: CollectionImage, dateFormat: DateFormat = .full, fontSize: FontSize = .caption, textColor: Color = .white) {
        self.image = image
        self.dateFormat = dateFormat
        self.fontSize = fontSize
        self.textColor = textColor
    }

    var body: some View {
        HStack(spacing: 4) {
            // Date and time
            Text(formattedDate)
                .font(fontSize.font)

            // Media type indicator (inline)
            if image.isLivePhoto {
                Text("•")
                    .font(fontSize.font)
                Image(systemName: "livephoto")
                    .font(fontSize.font)
                Text("LIVE")
                    .font(fontSize.font)
            } else if image.isVideo {
                // Play icon and duration (fades in when loaded, space reserved)
                HStack(spacing: 4) {
                    Text("•")
                        .font(fontSize.font)

                    Image(systemName: "play.fill")
                        .font(fontSize.font)

                    Text(displayDuration != nil ? VideoDurationHelper.formatDuration(displayDuration!) : "0:00")
                        .font(fontSize.font)
                }
                .opacity(displayDuration != nil ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: displayDuration != nil)
                .overlay {
                    // Hidden placeholder to reserve space
                    HStack(spacing: 4) {
                        Text("•")
                            .font(fontSize.font)

                        Image(systemName: "play.fill")
                            .font(fontSize.font)

                        Text("0:00")
                            .font(fontSize.font)
                    }
                    .hidden()
                }
            }
        }
        .foregroundStyle(textColor)
        .task(id: image.id) {
            // Priority 1: Use timezone from API response (already in model)
            if let apiTimezone = image.cachedTimezoneOffset {
                timezoneOffset = apiTimezone
            }
            // Priority 2: Check store cache (from previous video extraction)
            else if let cached = collectionImageStore.getCachedTimezoneOffset(for: image.id) {
                timezoneOffset = cached
            }
            // Priority 3: For Live Photos/videos, extract from video metadata as fallback
            else if (image.isLivePhoto || image.isVideo), let url = image.videoUrls?.videoUrl(for: .medium) {
                if let offset = await VideoMetadataHelper.extractTimezoneOffset(from: url) {
                    timezoneOffset = offset
                    // Cache for future use
                    await MainActor.run {
                        collectionImageStore.cacheTimezoneOffset(for: image.id, offset: offset)
                    }
                }
            }

            // Fetch video duration if not already available (for videos only)
            if image.isVideo, image.videoDuration == nil, let url = image.videoUrls?.videoUrl(for: .medium) {
                fetchedDuration = await VideoDurationHelper.getDuration(from: url)
            }
        }
    }

    private var formattedDate: String {
        // Use timezone-aware formatting if we have a timezone offset
        switch dateFormat {
        case .full:
            let datePart = formatDateMMMMdYYYYWithTimezone(image.date, timezoneOffset: timezoneOffset)
            let timePart = formatDateHHmmWithTimezone(image.date, timezoneOffset: timezoneOffset)
            return "\(datePart) • \(timePart)"
        case .short:
            let datePart = formatDateInOriginalTimezone(image.date, timezoneOffset: timezoneOffset, format: "MMMM dd")
            let timePart = formatDateHHmmWithTimezone(image.date, timezoneOffset: timezoneOffset)
            return "\(datePart) • \(timePart)"
        }
    }

    enum DateFormat {
        case full   // "January 15, 2025 • 2:30 PM"
        case short  // "January 15 • 2:30 PM"
    }

    enum FontSize {
        case caption
        case caption2

        var font: Font {
            switch self {
            case .caption: return .caption
            case .caption2: return .caption2
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Regular photo - full format
        DateMediaTypeLabel(
            image: CollectionImage(
                id: "1",
                mediaType: .PHOTO,
                date: Date()
            ),
            dateFormat: .full
        )

        // Live photo - short format
        DateMediaTypeLabel(
            image: CollectionImage(
                id: "2",
                mediaType: .LIVE,
                date: Date()
            ),
            dateFormat: .short,
            fontSize: .caption2
        )

        // Video with duration
        DateMediaTypeLabel(
            image: CollectionImage(
                id: "3",
                videoDuration: 125.5,
                mediaType: .VIDEO,
                date: Date()
            ),
            dateFormat: .full
        )
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
