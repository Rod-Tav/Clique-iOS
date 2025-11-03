//
//  UploadActivityAttributes.swift
//  Clique
//
//  Created by Claude Code on 11/2/25.
//

import Foundation
import ActivityKit

/// Defines the data structure for upload progress Live Activities.
///
/// This struct conforms to `ActivityAttributes` and provides the static and dynamic data
/// needed to display upload progress in the Dynamic Island and Lock Screen.
///
/// ## Static Properties (ActivityAttributes)
/// These properties are set once when the activity starts and never change:
/// - `collectionName`: The name of the collection being uploaded to
/// - `totalPhotos`: Total number of photos and videos being uploaded
/// - `cliqueId`: The ID of the clique (for deep linking)
///
/// ## Dynamic Properties (ContentState)
/// These properties update as the upload progresses:
/// - `uploadedPhotos`: Current count of uploaded items (integer for display)
/// - `totalProgress`: Precise fractional progress (0.0 to 1.0) for progress bar
/// - `currentStatus`: Upload state (processing, uploading, finalizing, completed, failed)
/// - `currentFileName`: Name of file currently being uploaded
/// - `uploadSpeed`: Upload speed in human-readable format (e.g., "2.3 MB/s")
/// - `estimatedTimeRemaining`: Seconds remaining (for time display)
///
/// ## Usage Example
/// ```swift
/// let attributes = UploadActivityAttributes(
///     collectionName: "Beach Trip 2025",
///     totalPhotos: 10,
///     cliqueId: "clique-123"
/// )
///
/// let initialState = UploadActivityAttributes.ContentState(
///     uploadedPhotos: 0,
///     totalProgress: 0.0,
///     currentStatus: .processing,
///     currentFileName: "",
///     uploadSpeed: nil,
///     estimatedTimeRemaining: nil
/// )
///
/// let activity = try await Activity.request(
///     attributes: attributes,
///     content: .init(state: initialState, staleDate: nil),
///     pushType: nil
/// )
/// ```
struct UploadActivityAttributes: ActivityAttributes {
    /// Dynamic content state that updates during upload
    public struct ContentState: Codable, Hashable {
        /// Number of photos uploaded (floor of fractional progress for display)
        var uploadedPhotos: Int

        /// Precise fractional progress from 0.0 to 1.0
        /// Used for smooth progress bar animation
        var totalProgress: Double

        /// Current upload status
        var currentStatus: LiveActivityUploadStatus

        /// Name of file currently being uploaded
        var currentFileName: String

        /// Upload speed in human-readable format (e.g., "2.3 MB/s")
        var uploadSpeed: String?

        /// Estimated time remaining in seconds
        var estimatedTimeRemaining: Int?
    }

    // MARK: - Static Properties (Set once at activity start)

    /// Name of the collection being uploaded to
    var collectionName: String

    /// Total number of photos/videos to upload
    var totalPhotos: Int

    /// Clique ID for deep linking
    var cliqueId: String
}

/// Live Activity upload status enum representing the current state of the upload process
enum LiveActivityUploadStatus: Codable, Hashable {
    case processing
    case uploading
    case finalizing
    case completed
    case failed(String)

    /// Human-readable display text for the status
    var displayText: String {
        switch self {
        case .processing:
            return "Processing"
        case .uploading:
            return "Uploading"
        case .finalizing:
            return "Finalizing"
        case .completed:
            return "Complete"
        case .failed:
            return "Failed"
        }
    }

    /// SF Symbol name for the status icon
    var systemImage: String {
        switch self {
        case .processing:
            return "photo.on.rectangle.angled"
        case .uploading:
            return "arrow.up.circle.fill"
        case .finalizing:
            return "checkmark.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Color for the status (for visual feedback)
    var statusColor: String {
        switch self {
        case .processing:
            return "blue"
        case .uploading:
            return "blue"
        case .finalizing:
            return "green"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }

    // MARK: - Codable Conformance

    enum CodingKeys: String, CodingKey {
        case type
        case errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "processing":
            self = .processing
        case "uploading":
            self = .uploading
        case "finalizing":
            self = .finalizing
        case "completed":
            self = .completed
        case "failed":
            let errorMessage = try container.decode(String.self, forKey: .errorMessage)
            self = .failed(errorMessage)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown upload status type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .processing:
            try container.encode("processing", forKey: .type)
        case .uploading:
            try container.encode("uploading", forKey: .type)
        case .finalizing:
            try container.encode("finalizing", forKey: .type)
        case .completed:
            try container.encode("completed", forKey: .type)
        case .failed(let errorMessage):
            try container.encode("failed", forKey: .type)
            try container.encode(errorMessage, forKey: .errorMessage)
        }
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        switch self {
        case .processing:
            hasher.combine("processing")
        case .uploading:
            hasher.combine("uploading")
        case .finalizing:
            hasher.combine("finalizing")
        case .completed:
            hasher.combine("completed")
        case .failed(let errorMessage):
            hasher.combine("failed")
            hasher.combine(errorMessage)
        }
    }

    // MARK: - Equatable Conformance

    static func == (lhs: LiveActivityUploadStatus, rhs: LiveActivityUploadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.processing, .processing),
             (.uploading, .uploading),
             (.finalizing, .finalizing),
             (.completed, .completed):
            return true
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
