//
//  UploadProgressTracker.swift
//  Clique
//
//  Created by Assistant for Live Activity upload progress tracking.
//

import Foundation

/// Tracks upload progress metrics including speed, ETA, and current filename
@Observable
final class UploadProgressTracker {

    // MARK: - Properties

    private var startTime: Date?
    private var totalBytesUploaded: Int64 = 0
    private var lastUpdateTime: Date?
    private var lastBytesUploaded: Int64 = 0

    private(set) var currentFilename: String = ""
    private(set) var uploadSpeed: Double = 0.0  // MB/s
    private(set) var estimatedTimeRemaining: Int = 0  // seconds

    // MARK: - Public Methods

    /// Starts tracking upload progress
    func start() {
        startTime = Date()
        lastUpdateTime = Date()
        totalBytesUploaded = 0
        lastBytesUploaded = 0
        currentFilename = ""
        uploadSpeed = 0.0
        estimatedTimeRemaining = 0
    }

    /// Updates progress with information about an uploaded item
    /// - Parameters:
    ///   - bytesUploaded: Number of bytes uploaded for this item
    ///   - filename: Name of the file being uploaded
    ///   - remainingItems: Number of items still to upload
    ///   - averageBytesPerItem: Average file size for remaining items (optional)
    func updateProgress(
        bytesUploaded: Int64,
        filename: String,
        remainingItems: Int,
        averageBytesPerItem: Int64? = nil
    ) {
        currentFilename = filename
        totalBytesUploaded += bytesUploaded

        guard let startTime = startTime else { return }

        let now = Date()
        let totalElapsedTime = now.timeIntervalSince(startTime)

        // Calculate upload speed based on total elapsed time (MB/s)
        if totalElapsedTime > 0 {
            let bytesPerSecond = Double(totalBytesUploaded) / totalElapsedTime
            uploadSpeed = bytesPerSecond / (1024 * 1024)  // Convert to MB/s
        }

        // Calculate ETA based on remaining items and current speed
        if uploadSpeed > 0, let avgBytes = averageBytesPerItem {
            let remainingBytes = Int64(remainingItems) * avgBytes
            let remainingSeconds = Double(remainingBytes) / (uploadSpeed * 1024 * 1024)
            estimatedTimeRemaining = Int(remainingSeconds.rounded())
        } else if remainingItems > 0, totalElapsedTime > 0 {
            // Fallback: estimate based on average time per item
            let itemsCompleted = max(1, totalBytesUploaded / max(1, averageBytesPerItem ?? 1))
            let averageTimePerItem = totalElapsedTime / Double(itemsCompleted)
            estimatedTimeRemaining = Int((averageTimePerItem * Double(remainingItems)).rounded())
        } else {
            estimatedTimeRemaining = 0
        }

        lastUpdateTime = now
        lastBytesUploaded = bytesUploaded
    }

    /// Returns formatted speed string
    /// - Returns: Speed formatted as "X.X MB/s" or "X KB/s"
    func formattedSpeed() -> String {
        if uploadSpeed >= 1.0 {
            return String(format: "%.1f MB/s", uploadSpeed)
        } else {
            let kbps = uploadSpeed * 1024
            return String(format: "%.0f KB/s", kbps)
        }
    }

    /// Returns formatted ETA string
    /// - Returns: ETA formatted as "Xm Ys" or "Xs"
    func formattedETA() -> String {
        if estimatedTimeRemaining <= 0 {
            return "Calculating..."
        }

        let minutes = estimatedTimeRemaining / 60
        let seconds = estimatedTimeRemaining % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Resets all tracking data
    func reset() {
        startTime = nil
        lastUpdateTime = nil
        totalBytesUploaded = 0
        lastBytesUploaded = 0
        currentFilename = ""
        uploadSpeed = 0.0
        estimatedTimeRemaining = 0
    }
}
