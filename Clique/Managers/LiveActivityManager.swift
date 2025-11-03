//
//  LiveActivityManager.swift
//  Clique
//
//  Created by Claude Code on 11/2/25.
//

import Foundation
import ActivityKit
import SwiftUI

/// Manages the lifecycle of Live Activities for upload progress tracking.
///
/// This singleton class provides a centralized interface for starting, updating,
/// and ending Live Activities. It ensures only one upload activity is active at a time
/// and handles the ActivityKit API interactions.
///
/// ## Usage Example
/// ```swift
/// // Start a Live Activity
/// let attributes = UploadActivityAttributes(
///     collectionName: "Beach Trip",
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
/// try await LiveActivityManager.shared.startActivity(
///     attributes: attributes,
///     contentState: initialState
/// )
///
/// // Update progress
/// let updatedState = UploadActivityAttributes.ContentState(
///     uploadedPhotos: 5,
///     totalProgress: 0.5,
///     currentStatus: .uploading,
///     currentFileName: "IMG_1234.HEIC",
///     uploadSpeed: "2.5 MB/s",
///     estimatedTimeRemaining: 60
/// )
/// await LiveActivityManager.shared.updateActivity(updatedState)
///
/// // End activity
/// let finalState = UploadActivityAttributes.ContentState(
///     uploadedPhotos: 10,
///     totalProgress: 1.0,
///     currentStatus: .completed,
///     currentFileName: "",
///     uploadSpeed: nil,
///     estimatedTimeRemaining: nil
/// )
/// await LiveActivityManager.shared.endActivity(
///     finalState: finalState,
///     dismissalPolicy: .after(4.0)
/// )
/// ```
///
/// ## Thread Safety
/// All methods are marked `@MainActor` to ensure UI updates happen on the main thread.
///
/// ## Activity Lifecycle
/// 1. **Check Permission**: Use `areActivitiesEnabled` before starting
/// 2. **Start**: Creates a new Live Activity with initial state
/// 3. **Update**: Updates the activity's content state as upload progresses
/// 4. **End**: Finalizes the activity with dismissal policy
@MainActor
class LiveActivityManager: ObservableObject {
    /// Shared singleton instance
    static let shared = LiveActivityManager()

    /// Current active upload activity (nil if no activity is running)
    @Published private(set) var currentActivity: Activity<UploadActivityAttributes>?

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Check if Live Activities are enabled by the user
    ///
    /// This should be checked before attempting to start a Live Activity.
    /// If the user has disabled Live Activities in Settings, this will return false.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts a new Live Activity for upload progress tracking
    ///
    /// - Parameters:
    ///   - attributes: Static attributes (collection name, total photos, clique ID)
    ///   - contentState: Initial dynamic state (progress, status, etc.)
    /// - Returns: The created Activity instance
    /// - Throws: ActivityKit errors if the activity cannot be started
    ///
    /// - Important: Only one upload activity can be active at a time. If an activity
    ///   is already running, it will be ended before starting the new one.
    func startActivity(
        attributes: UploadActivityAttributes,
        contentState: UploadActivityAttributes.ContentState
    ) async throws -> Activity<UploadActivityAttributes> {
        // End any existing activity before starting a new one
        if let existingActivity = currentActivity {
            await existingActivity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }

        // Request a new Live Activity
        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: nil),
            pushType: nil
        )

        currentActivity = activity
        print("✅ Live Activity started: \(activity.id)")

        return activity
    }

    /// Updates the current Live Activity with new progress state
    ///
    /// - Parameter newState: The updated content state with new progress information
    ///
    /// This method should be called frequently during upload to keep the Live Activity
    /// in sync with actual upload progress. Updates are throttled by ActivityKit to
    /// prevent excessive battery drain.
    ///
    /// - Note: If no activity is currently running, this method does nothing.
    func updateActivity(_ newState: UploadActivityAttributes.ContentState) async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }

        await activity.update(.init(state: newState, staleDate: nil))
    }

    /// Ends the current Live Activity with a final state
    ///
    /// - Parameters:
    ///   - finalState: The final content state to display before dismissal
    ///   - dismissalPolicy: When the activity should be dismissed from the UI
    ///
    /// ## Dismissal Policies
    /// - `.immediate`: Removes the activity immediately
    /// - `.default`: Lets the system decide when to remove (typically after a few seconds)
    /// - `.after(TimeInterval)`: Removes after the specified duration (e.g., 4 seconds)
    ///
    /// - Note: If no activity is currently running, this method does nothing.
    func endActivity(
        finalState: UploadActivityAttributes.ContentState,
        dismissalPolicy: ActivityUIDismissalPolicy = .default
    ) async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to end")
            return
        }

        // Update with final state, then end with dismissal policy
        await activity.update(.init(state: finalState, staleDate: nil))
        await activity.end(nil, dismissalPolicy: dismissalPolicy)

        currentActivity = nil
        print("✅ Live Activity ended with dismissal policy: \(dismissalPolicy)")
    }

    /// Ends the current Live Activity immediately without a final state update
    ///
    /// This is useful for canceling an upload or handling errors where you don't
    /// want to show a final state.
    func cancelActivity() async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to cancel")
            return
        }

        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
        print("✅ Live Activity canceled")
    }
}
