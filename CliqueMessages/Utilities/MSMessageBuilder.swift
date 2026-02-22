//
//  MSMessageBuilder.swift
//  CliqueMessages
//
//  Utility for creating rich iMessage bubbles for sharing Clique content
//

import Foundation
import Messages
import UIKit
import CliqueCore

/// Utility for building rich MSMessage objects with MSMessageTemplateLayout for sharing Clique content.
///
/// This builder creates interactive iMessage bubbles that display Clique content with rich metadata
/// and deep links that open the main Clique app to the correct content when tapped.
///
/// ## iMessage Framework Overview
///
/// The Messages framework provides two key types for creating rich message bubbles:
///
/// ### MSMessage
/// The core message object that encapsulates:
/// - **URL**: Deep link that opens when the bubble is tapped
/// - **Layout**: Visual appearance of the bubble (using MSMessageTemplateLayout)
/// - **Session**: Optional identifier to group related messages
///
/// ### MSMessageTemplateLayout
/// Defines the visual structure of a message bubble with these properties:
/// - **image**: Main visual (UIImage) - appears at top of bubble
/// - **imageTitle**: Text overlaid on the image (e.g., "Summer Vacation")
/// - **imageSubtitle**: Secondary text on the image (e.g., "Beach Collection")
/// - **caption**: Primary text below image (e.g., "@john shared a flick")
/// - **subcaption**: Secondary text below caption (e.g., "2 hours ago")
/// - **trailingCaption**: Badge on right side (e.g., "24 flicks")
/// - **trailingSubcaption**: Secondary badge text (e.g., "New")
///
/// ## Visual Layout Structure
/// ```
/// ┌─────────────────────────────────────┐
/// │                                     │
/// │          [Main Image]               │
/// │      imageTitle (overlay)           │
/// │     imageSubtitle (overlay)         │
/// │                                     │
/// ├─────────────────────────────────────┤
/// │ caption                trailingCap  │
/// │ subcaption          trailingSub     │
/// └─────────────────────────────────────┘
/// ```
///
/// ## Deep Link Integration
///
/// All messages use the ``DeepLinkBuilder`` from CliqueCore to create URLs that:
/// - Use the `clique://` custom URL scheme
/// - Include source tracking (`?src=imessage`)
/// - Navigate to the correct content when tapped
///
/// When a user taps a message bubble:
/// 1. iOS opens the Clique app via the deep link URL
/// 2. App parses the URL using ``DeepLinkBuilder.parse(_:)``
/// 3. App navigates to the appropriate view (flick, collection, or clique)
///
/// ## Usage Examples
///
/// ### Sharing a Flick
/// ```swift
/// let message = MSMessageBuilder.buildFlickMessage(
///     flick: cachedFlick,
///     collection: cachedCollection,
///     clique: cachedClique,
///     senderUsername: "john_doe",
///     thumbnail: flickImage
/// )
/// conversation?.insert(message)
/// ```
///
/// ### Sharing a Collection
/// ```swift
/// let message = MSMessageBuilder.buildCollectionMessage(
///     collection: cachedCollection,
///     clique: cachedClique,
///     senderUsername: "jane_smith",
///     coverImage: collectionCover
/// )
/// conversation?.insert(message)
/// ```
///
/// ### Sending a Clique Invitation
/// ```swift
/// let message = MSMessageBuilder.buildCliqueInviteMessage(
///     clique: cachedClique,
///     senderUsername: "mike_jones",
///     cliqueImage: cliqueThumb
/// )
/// conversation?.insert(message)
/// ```
///
/// ## Implementation Notes
///
/// - All images should be provided as UIImage (already loaded)
/// - Thumbnail images are recommended (300-500px) for performance
/// - Text is automatically truncated by iOS if too long
/// - Deep links use the standard Clique URL scheme
/// - Session IDs can be used to group related messages
///
/// - SeeAlso: ``DeepLinkBuilder`` for URL scheme documentation
public struct MSMessageBuilder {

    // MARK: - Flick Message

    /// Builds an MSMessage for sharing a flick from a collection.
    ///
    /// Creates a rich iMessage bubble showing the flick thumbnail with metadata about
    /// the collection and clique it belongs to. When tapped, opens the main Clique app
    /// directly to the flick detail view.
    ///
    /// The visual layout shows:
    /// - **Image**: Flick thumbnail
    /// - **Image Title**: Clique name (e.g., "Summer Vacation")
    /// - **Image Subtitle**: Collection name (e.g., "Beach Day")
    /// - **Caption**: "@username shared a flick"
    /// - **Subcaption**: Date posted (e.g., "2 hours ago")
    /// - **Trailing Caption**: Collection flick count (e.g., "24 flicks")
    ///
    /// - Parameters:
    ///   - flick: The cached flick being shared
    ///   - collection: The collection containing the flick
    ///   - clique: The clique containing the collection
    ///   - senderUsername: Username of the person sharing (without @ prefix)
    ///   - thumbnail: Pre-loaded thumbnail image for the flick
    /// - Returns: Configured MSMessage ready to send via Messages framework
    ///
    /// - Note: The deep link URL format is `clique://flick/{flickId}?src=imessage`
    public static func buildFlickMessage(
        flick: CachedFlick,
        collection: CachedCollection,
        clique: CachedClique,
        senderUsername: String,
        thumbnail: UIImage
    ) -> MSMessage {
        // Create the message and layout
        let message = MSMessage()
        let layout = MSMessageTemplateLayout()

        // Set the main image
        layout.image = thumbnail

        // Image overlays
        layout.imageTitle = clique.name
        layout.imageSubtitle = collection.name

        // Caption text
        layout.caption = "@\(senderUsername) shared a flick"
        layout.subcaption = timeAgoString(from: flick.createdAt)

        // Trailing badge (collection info)
        layout.trailingCaption = "\(collection.flickCount) flicks"
        layout.trailingSubcaption = visibilityString(collection.visibility)

        // Set the deep link URL
        let deepLinkURL = DeepLinkBuilder.flickURL(flickId: flick.id)
        message.url = deepLinkURL

        // Apply layout
        message.layout = layout

        // Note: MSMessage.session is read-only in newer iOS versions
        // It's automatically set by the Messages framework when the message is created

        return message
    }

    // MARK: - Collection Message

    /// Builds an MSMessage for sharing an entire collection.
    ///
    /// Creates a rich iMessage bubble showing the collection cover image with metadata.
    /// When tapped, opens the main Clique app to the collection view within the clique.
    ///
    /// The visual layout shows:
    /// - **Image**: Collection cover image
    /// - **Image Title**: Collection name (e.g., "Beach Day")
    /// - **Image Subtitle**: Clique name (e.g., "Summer Vacation")
    /// - **Caption**: "@username shared a collection"
    /// - **Subcaption**: Date created (e.g., "1 week ago")
    /// - **Trailing Caption**: Flick count (e.g., "24 flicks")
    /// - **Trailing Subcaption**: Visibility status
    ///
    /// - Parameters:
    ///   - collection: The cached collection being shared
    ///   - clique: The clique containing the collection
    ///   - senderUsername: Username of the person sharing (without @ prefix)
    ///   - coverImage: Pre-loaded cover image for the collection
    /// - Returns: Configured MSMessage ready to send via Messages framework
    ///
    /// - Note: The deep link URL format is `clique://clique/{cliqueId}/collection/{collectionId}?src=imessage`
    public static func buildCollectionMessage(
        collection: CachedCollection,
        clique: CachedClique,
        senderUsername: String,
        coverImage: UIImage
    ) -> MSMessage {
        // Create the message and layout
        let message = MSMessage()
        let layout = MSMessageTemplateLayout()

        // Set the main image
        layout.image = coverImage

        // Image overlays
        layout.imageTitle = collection.name
        layout.imageSubtitle = clique.name

        // Caption text
        layout.caption = "@\(senderUsername) shared a collection"
        layout.subcaption = timeAgoString(from: collection.createdAt)

        // Trailing badge (collection info)
        let flickCountText = collection.flickCount == 1 ? "1 flick" : "\(collection.flickCount) flicks"
        layout.trailingCaption = flickCountText
        layout.trailingSubcaption = visibilityString(collection.visibility)

        // Set the deep link URL
        let deepLinkURL = DeepLinkBuilder.collectionURL(
            cliqueId: clique.id,
            collectionId: collection.id
        )
        message.url = deepLinkURL

        // Apply layout
        message.layout = layout

        return message
    }

    // MARK: - Clique Invitation Message

    /// Builds an MSMessage for inviting someone to join a clique.
    ///
    /// Creates a rich iMessage bubble inviting the recipient to join a clique.
    /// When tapped, opens the main Clique app to the clique profile page where
    /// they can request to join or view clique details.
    ///
    /// The visual layout shows:
    /// - **Image**: Clique thumbnail/cover image
    /// - **Image Title**: Clique name (e.g., "Summer Vacation")
    /// - **Image Subtitle**: "Private Group"
    /// - **Caption**: "@username invited you to join"
    /// - **Subcaption**: "Tap to view in Clique"
    /// - **Trailing Caption**: Member count (e.g., "12 members")
    /// - **Trailing Subcaption**: Flick count (e.g., "156 flicks")
    ///
    /// - Parameters:
    ///   - clique: The cached clique for the invitation
    ///   - senderUsername: Username of the person sending invitation (without @ prefix)
    ///   - cliqueImage: Pre-loaded thumbnail image for the clique
    /// - Returns: Configured MSMessage ready to send via Messages framework
    ///
    /// - Note: The deep link URL format is `clique://clique/{cliqueId}?src=imessage`
    public static func buildCliqueInviteMessage(
        clique: CachedClique,
        senderUsername: String,
        cliqueImage: UIImage
    ) -> MSMessage {
        // Create the message and layout
        let message = MSMessage()
        let layout = MSMessageTemplateLayout()

        // Set the main image
        layout.image = cliqueImage

        // Image overlays
        layout.imageTitle = clique.name
        layout.imageSubtitle = "Private Group"

        // Caption text
        layout.caption = "@\(senderUsername) invited you to join"
        layout.subcaption = "Tap to view in Clique"

        // Trailing badge (clique stats)
        let memberText = clique.memberCount == 1 ? "1 member" : "\(clique.memberCount) members"
        let flickText = clique.flickCount == 1 ? "1 flick" : "\(clique.flickCount) flicks"
        layout.trailingCaption = memberText
        layout.trailingSubcaption = flickText

        // Set the deep link URL
        let deepLinkURL = DeepLinkBuilder.cliqueURL(cliqueId: clique.id)
        message.url = deepLinkURL

        // Apply layout
        message.layout = layout

        return message
    }

    // MARK: - Helper Functions

    /// Converts a date to a human-readable "time ago" string.
    ///
    /// - Parameter date: The date to convert
    /// - Returns: A string like "2 hours ago", "1 week ago", etc.
    private static func timeAgoString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Seconds
        if interval < 60 {
            return "Just now"
        }

        // Minutes
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }

        // Hours
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }

        // Days
        if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }

        // Weeks
        if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }

        // Months
        if interval < 31536000 {
            let months = Int(interval / 2592000)
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }

        // Years
        let years = Int(interval / 31536000)
        return years == 1 ? "1 year ago" : "\(years) years ago"
    }

    /// Converts a Visibility enum to a user-friendly string.
    ///
    /// - Parameter visibility: The visibility level
    /// - Returns: A string like "Public", "Private", etc.
    private static func visibilityString(_ visibility: Visibility) -> String {
        switch visibility {
        case .pub:
            return "Public"
        case .followers:
            return "Followers"
        case .priv:
            return "Private"
        }
    }
}
