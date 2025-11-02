//
//  PhotoHelper.swift
//  Clique
//
//  Created by Rod Tavangar on 1/29/25.
//

import Foundation
import UIKit
import CryptoKit
import Network
import Photos  // For PHAsset in just-in-time video extraction

/// Prepares image data for upload (original quality only - backend handles quality variants)
func prepareUIImage(_ uiImage: UIImage?) -> (photoData: Components.Schemas.PhotoDataNoPath, imageVariant: PreparedImageVariant)? {
    guard let uiImage else { return nil }

    /// Helper function to generate UploadPhotoParams and keep Data
    func createUploadPhotoParams(from image: UIImage, quality: CGFloat) -> PreparedImageVariant? {
        // Use original image (no resizing - backend handles quality variants)
        guard let imageData = image.jpegData(compressionQuality: quality) else { return nil }

        // Create MD5 hash for integrity check
        let hash = Insecure.MD5.hash(data: imageData)
        let hashData = Data(hash)
        let base64String = hashData.base64EncodedString()
        let numBytes = imageData.count

        let params = Components.Schemas.UploadPhotoParams(
            contentType: "image/jpeg",
            contentLength: Int64(numBytes),
            contentMd5: base64String
        )

        return PreparedImageVariant(data: imageData, params: params)
    }

    // Only create original quality (1.0 = no compression) - backend handles quality conversion
    guard let original = createUploadPhotoParams(from: uiImage, quality: 1.0) else {
        return nil
    }

    print("Original Quality: \(original.params.contentLength ?? 0) bytes, MD5: \(original.params.contentMd5 ?? "")")

    // Send same params for all three - backend requires all three (even though it will handle quality conversion)
    let photoData = Components.Schemas.PhotoDataNoPath(
        basePhoto: original.params,
        medQualityPhoto: original.params,
        lowQualityPhoto: original.params
    )

    return (photoData, original)
}

actor FailedVariantTracker {
    private var failed: [Int: Set<ImageQuality>] = [:]

    func insert(_ index: Int, quality: ImageQuality) {
        failed[index, default: []].insert(quality)
    }

    func isEmpty() -> Bool {
        failed.isEmpty
    }
}

/// Tracks completion of media items (each item may have photo + video components)
/// Uses fractional progress to show partial completion (e.g., 0.5 when photo done, 1.0 when both done)
actor ItemCompletionTracker {
    private var completedPhotos: Set<Int> = []
    private var completedVideos: Set<Int> = []
    private var itemsWithVideo: Set<Int> = [] // Track which items have videos
    private let totalItems: Int

    init(totalItems: Int) {
        self.totalItems = totalItems
    }

    /// Register that an item has a video component
    func registerItemWithVideo(index: Int) {
        itemsWithVideo.insert(index)
    }

    /// Mark photo component as complete for an item index
    /// Returns fractional progress (current completion / total items)
    func markPhotoComplete(index: Int) -> Double {
        completedPhotos.insert(index)
        return calculateProgress()
    }

    /// Mark video component as complete for an item index
    /// Returns fractional progress (current completion / total items)
    func markVideoComplete(index: Int) -> Double {
        completedVideos.insert(index)
        return calculateProgress()
    }

    /// Calculate fractional progress
    /// Each item contributes 1.0 to total. Items with videos: photo=0.5, video=0.5
    private func calculateProgress() -> Double {
        var progress: Double = 0.0

        for index in 0..<totalItems {
            let hasVideo = itemsWithVideo.contains(index)
            let photoComplete = completedPhotos.contains(index)
            let videoComplete = completedVideos.contains(index)

            if hasVideo {
                // Item has video: photo and video each worth 0.5
                if photoComplete {
                    progress += 0.5
                }
                if videoComplete {
                    progress += 0.5
                }
            } else {
                // Item is photo-only: photo worth 1.0
                if photoComplete {
                    progress += 1.0
                }
            }
        }

        return progress
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Returns an opaque version of the image to avoid transparency-related warnings.
    func withoutAlpha() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(at: .zero)
        }
    }
}

// MARK: - Upload Type Enum

enum UploadType: String {
    case newCollection, existingCollection
}

// MARK: - Image Quality Enum

enum ImageQuality: String {
    case high, medium, low
}

// MARK: - Photo Helper

struct PhotoHelper {
    static func createPhotoDatePairs(images: [UIImage], dates: [Date]) -> [Components.Schemas.PhotoVideoDate] {
        return zip(images, dates).map { image, date in
            let prepared = prepareUIImage(image)
            return mapToPhotoDatePair(photo: prepared?.photoData, date: date)
        }
    }
    
    private static func uploadDataToS3(
        data: Data,
        urlString: String,
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws {
        try await withCheckedThrowingContinuation { cont in
            var resumed = false
            
            // Start the upload
            uploadUIImageDataToS3(
                data: data,
                to: urlString,
                progressHandler: progress
            ) { result in
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success:
                    cont.resume()
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            
            // Failsafe timeout (e.g. 45 seconds)
            DispatchQueue.global().asyncAfter(deadline: .now() + 45) {
                guard !resumed else { return }
                resumed = true
                cont.resume(throwing: URLError(.timedOut))
            }
        }
    }
    
    static func uploadImage(_ image: UIImage?, to url: String?, progressHandler: @escaping (Double) -> Void = { _ in }) async throws {
        guard let image, let url else { return }
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            throw PhotoUploadError.imageConversionFailed
        }
        try await uploadDataToS3(data: data, urlString: url, progress: progressHandler)
    }
    
    static func uploadUIImageDataToS3(
        data: Data,
        to urlString: String,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uploadUrl = URL(string: urlString) else {
            completion(.failure(PhotoUploadError.invalidUrl))
            return
        }

        let hash = Insecure.MD5.hash(data: data)
        let hashData = Data(hash)
        let base64String = hashData.base64EncodedString()
        let numBytes = data.count

        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(numBytes)", forHTTPHeaderField: "Content-Length")
        request.setValue(base64String, forHTTPHeaderField: "Content-MD5")
        request.setValue("AES256", forHTTPHeaderField: "x-amz-server-side-encryption")

        PhotoUploader.shared.uploadImage(request: request,
                                         data: data,
                                         progressHandler: progressHandler,
                                         completion: completion)
    }
    
    static func uploadImageData(_ data: Data, to url: String?, progressHandler: @escaping (Double) -> Void = { _ in }) async throws {
        guard let url else { return }
        try await uploadDataToS3(data: data, urlString: url, progress: progressHandler)
    }
    
    /// Run an async operation with a timeout.
    private static func withTimeout<T>(
        seconds: TimeInterval,
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // Shared helper for evaluating network path and returning a value based on interface type.
    private static func evaluateNetworkPath<T>(defaultValue: T, timeout: DispatchTime, evaluator: @escaping (NWPath) -> T) -> T {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var result = defaultValue
        
        monitor.pathUpdateHandler = { path in
            result = evaluator(path)
            semaphore.signal()
            monitor.cancel()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor.\(UUID().uuidString)")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: timeout)
        return result
    }
    
    static func currentNetworkTimeout() -> TimeInterval {
        evaluateNetworkPath(defaultValue: 15, timeout: .now() + 0.1) { path in
            if path.usesInterfaceType(.wifi) {
                return 12
            } else if path.usesInterfaceType(.cellular) {
                return 22
            } else {
                return 18
            }
        }
    }
    
    private static func currentNetworkBaseDelay() -> TimeInterval {
        evaluateNetworkPath(defaultValue: 2.0, timeout: .now() + 0.1) { path in
            if path.usesInterfaceType(.wifi) {
                return 1.5
            } else if path.usesInterfaceType(.cellular) {
                return 2.5
            } else {
                return 2.0
            }
        }
    }
    
    /// Compute timeout dynamically based on network type *and* file size.
    /// Adds ~1.5 s per MB (capped at +8 s) on top of the base timeout.
    private static func dynamicTimeout(for data: Data) -> TimeInterval {
        let base = currentNetworkTimeout()
        let sizeInMB = Double(data.count) / 1_048_576.0        // 1 MB = 1_048_576 bytes
        let extra = min(8.0, sizeInMB * 1.5)                   // cap extra at 8 s
        return base + extra
    }
    
    /// Upload with timeout + exponential‑back‑off retries.
    private static func uploadImageDataWithRetry(
        _ data: Data,
        to url: String,
        attempts: Int = 3
    ) async throws {
        var delay = currentNetworkBaseDelay()
        var attempt = 1
        var lastError: Error?
        
        while attempt <= attempts {
            do {
                let timeout = dynamicTimeout(for: data)
                try await withTimeout(seconds: timeout) {
                    try await uploadImageData(data, to: url)
                }
                return
            } catch {
                // Print failure
                print("⚠️ Upload attempt \(attempt) failed: \(error.localizedDescription)")
                lastError = error
                attempt += 1
                if attempt > attempts { break }
                
                let jitter = Double.random(in: 0.75...1.25)
                try await Task.sleep(nanoseconds: UInt64(delay * jitter * 1_000_000_000))
                // Print retry info
                print("⏳ Retrying in \(String(format: "%.2f", delay * jitter)) seconds (base: \(delay))")
                delay *= 2
            }
        }
        throw lastError ?? URLError(.timedOut)
    }
    
    /// Upload images with optional video components (for Live Photos)
    /// - Parameters:
    ///   - preparedImages: Array of prepared image variants (original quality only)
    ///   - urls: Array of photo URLs (original quality only - backend handles conversion)
    ///   - livePhotoAssets: Optional array of PHAsset references for Live Photos (video extracted just-in-time)
    ///   - videoUrls: Optional array of video URLs for uploading video components
    ///   - totalItems: Total number of media items (for display - not upload task count)
    ///   - onProgress: Progress callback (fractional progress [0.0-totalItems], total items)
    ///   - failedUpload: Failure callback (index, quality)
    ///   - onCompletion: Completion callback (success)
    static func uploadImages(
        preparedImages: [PreparedImageVariant],
        urls: [String?],
        livePhotoAssets: [(assetId: String, asset: PHAsset)?]? = nil,
        transcodedVideoUrls: [URL?]? = nil,
        videoUrls: [String?]? = nil,
        videoContentTypes: [String?]? = nil,
        totalItems: Int,
        onProgress: @escaping (Double, Int) -> Void,
        failedUpload: @escaping (Int, ImageQuality) -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) async {
        // Calculate total uploads (1 photo per image + optional video)
        // This is for internal tracking - we report totalItems to the user
        var totalUploads = urls.compactMap { $0 }.count

        // Add video uploads to total count
        if let videoUrls = videoUrls {
            totalUploads += videoUrls.compactMap { $0 }.count
        }

        let counter = UploadCounter()
        let itemCompletionTracker = ItemCompletionTracker(totalItems: totalItems)
        let semaphore = AsyncSemaphore(value: 6)
        let failedTracker = FailedVariantTracker()

        // Register which items have videos before starting uploads
        if let transcodedVideoUrls = transcodedVideoUrls {
            for (index, videoUrl) in transcodedVideoUrls.enumerated() {
                if videoUrl != nil {
                    await itemCompletionTracker.registerItemWithVideo(index: index)
                }
            }
        }

        await withTaskGroup(of: Void.self) { taskGroup in

            func addUploadTask(data: Data, url: String, index: Int, quality: ImageQuality) {
                taskGroup.addTask {
                    await semaphore.wait()

                    do {
                        try await uploadImageDataWithRetry(data, to: url)
                        let _ = await counter.increment()

                        // Mark photo as complete for this item and report fractional progress
                        let fractionalProgress = await itemCompletionTracker.markPhotoComplete(index: index)
                        await MainActor.run {
                            onProgress(fractionalProgress, totalItems)
                        }
                    } catch {
                        await failedTracker.insert(index, quality: quality)
                        failedUpload(index, quality)
                        print("❌ Upload failed for \(quality.rawValue.uppercased()) quality at index \(index): \(error.localizedDescription)")
                    }

                    await semaphore.signal()
                }
            }

            func addVideoUploadTask(videoFileUrl: URL, url: String, index: Int, contentType: String) {
                taskGroup.addTask {
                    await semaphore.wait()

                    do {
                        // Use prepared video file (MOV or MP4)
                        print("⏳ Uploading video at index \(index)...")

                        // Stream upload directly from file (no memory spike)
                        try await uploadVideoFromFile(videoFileUrl, to: url, contentType: contentType)
                        let _ = await counter.increment()

                        // Mark video as complete for this item and report fractional progress
                        let fractionalProgress = await itemCompletionTracker.markVideoComplete(index: index)
                        await MainActor.run {
                            onProgress(fractionalProgress, totalItems)
                        }
                        print("✅ Video uploaded for index \(index)")
                    } catch {
                        await failedTracker.insert(index, quality: .high) // Mark as failed
                        failedUpload(index, .high) // Use .high to indicate video failure
                        print("❌ Video upload failed at index \(index): \(error.localizedDescription)")
                    }

                    await semaphore.signal()
                }
            }

            // Upload original quality only (backend handles quality conversion)
            for (index, imageVariant) in preparedImages.enumerated() {
                guard index < urls.count, let url = urls[index] else { continue }
                addUploadTask(data: imageVariant.data, url: url, index: index, quality: .high)
            }

            // Upload video components (for Live Photos and standalone videos) - use prepared videos
            if let transcodedVideoUrls = transcodedVideoUrls, let videoUrls = videoUrls {
                for (index, videoFileUrl) in transcodedVideoUrls.enumerated() {
                    guard let videoFileUrl = videoFileUrl,
                          index < videoUrls.count,
                          let uploadUrl = videoUrls[index] else { continue }

                    // Get content-type for this video (default to video/mp4 for backward compatibility)
                    let contentType = (videoContentTypes?[safe: index] ?? nil) ?? "video/mp4"

                    addVideoUploadTask(videoFileUrl: videoFileUrl, url: uploadUrl, index: index, contentType: contentType)
                }
            }
        }

        let allSucceeded = await failedTracker.isEmpty()
        await MainActor.run {
            onCompletion(allSucceeded)
        }
    }

    /// Calculate MD5 hash of file by streaming (memory efficient)
    private static func calculateMD5(of fileURL: URL) throws -> String {
        let bufferSize = 1024 * 1024 // 1MB buffer
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }

        var hasher = Insecure.MD5()

        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) { }

        let digest = hasher.finalize()
        return Data(digest).base64EncodedString()
    }

    /// Upload video from file URL to S3 with streaming (memory efficient)
    /// - Parameters:
    ///   - fileURL: Local file URL containing video data
    ///   - url: S3 presigned URL
    ///   - contentType: The content-type to use for upload (e.g., "video/quicktime", "video/mp4")
    /// - Important: Streams from disk - does NOT load entire file into memory
    private static func uploadVideoFromFile(_ fileURL: URL, to url: String, contentType: String) async throws {
        guard let uploadUrl = URL(string: url) else {
            throw PhotoUploadError.invalidUrl
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0

        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "Content-Length")
        // Note: No Content-MD5 for videos - backend doesn't include it in presigned URL signature
        request.setValue("AES256", forHTTPHeaderField: "x-amz-server-side-encryption")

        print("📤 Video upload request:")
        print("   Content-Type: \(contentType)")
        print("   Content-Length: \(fileSize)")
        print("   File: \(fileURL.lastPathComponent)")

        // Stream upload from file (memory efficient)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false

            let session = URLSession.shared
            let uploadTask = session.uploadTask(with: request, fromFile: fileURL) { data, response, error in
                guard !resumed else { return }
                resumed = true

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Video upload: No HTTP response")
                    continuation.resume(throwing: PhotoUploadError.uploadFailed)
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ Video upload failed: HTTP \(httpResponse.statusCode)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("   Response body: \(body)")
                    }
                    continuation.resume(throwing: PhotoUploadError.uploadFailed)
                    return
                }

                continuation.resume(returning: ())
            }

            uploadTask.resume()

            // Failsafe timeout (longer for video uploads)
            DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                guard !resumed else { return }
                resumed = true
                uploadTask.cancel()
                continuation.resume(throwing: URLError(.timedOut))
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    /// Safe array subscript that returns nil if index is out of bounds
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

actor UploadCounter {
    private var count = 0
    
    func increment() -> Int {
        count += 1
        return count
    }
    
    func value() -> Int {
        count
    }
}

// MARK: - PhotoUploader Singleton

final class PhotoUploader: NSObject, URLSessionTaskDelegate {
    
    static let shared = PhotoUploader()
    
    private struct Handlers {
        let progress: (Double) -> Void
    }
    
    private let syncQueue = DispatchQueue(label: "PhotoUploader.Sync")
    private var callbacks: [Int : Handlers] = [:]
    
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.allowsCellularAccess  = true
        cfg.timeoutIntervalForRequest = 60
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()
    
    /// Uploads `data` to S3 with exponential‑back‑off and a Swift‑Concurrency timeout.
    /// Progress is streamed via the URLSession delegate; the `completion` closure is
    /// invoked on success or after the final failed attempt.
    ///
    /// Back‑off schedule: 0.5 s → 1 s → 2 s  (max 3 attempts)
    func uploadImage(
        request: URLRequest,
        data: Data,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task.detached { [weak self] in
            guard let self else { return }

            do {
                let timeout = Self.dynamicTimeout(for: data)

                try await self.withTimeout(seconds: timeout) {
                    try await self.performSingleUpload(
                        request: request,
                        data: data,
                        progressHandler: progressHandler
                    )
                }

                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Executes an async operation with a timeout.
    private func withTimeout<T>(
        seconds: TimeInterval,
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Performs a single PUT upload and returns when the server responds or an error occurs.
    private func performSingleUpload(
        request: URLRequest,
        data: Data,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { [weak self] (cont: CheckedContinuation<Void, Error>) in
            guard let self else {
                cont.resume(throwing: URLError(.cancelled))
                return
            }
            
            let startTime = Date()
            // Declare the task up‑front so the completion handler can reference it safely
            var uploadTask: URLSessionUploadTask!
            
            uploadTask = self.session.uploadTask(with: request, from: data) { [weak self] _, response, error in
                let duration = Date().timeIntervalSince(startTime)
                print("📊 Upload duration for task \(uploadTask.taskIdentifier): \(duration) seconds")

                if let error = error {
                    cont.resume(throwing: error)
                } else if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        cont.resume(returning: ())
                    } else {
                        print("❌ S3 Upload failed with status code: \(http.statusCode)")
                        print("❌ Response headers: \(http.allHeaderFields)")
                        cont.resume(throwing: PhotoUploadError.uploadFailed)
                    }
                } else {
                    print("❌ No HTTP response received")
                    cont.resume(throwing: PhotoUploadError.uploadFailed)
                }
                
                // Clean‑up callback storage
                self?.syncQueue.async {
                    self?.callbacks[uploadTask.taskIdentifier] = nil
                }
            }
            
            // Store progress handler so delegate can report progress
            self.syncQueue.async {
                self.callbacks[uploadTask.taskIdentifier] = Handlers(progress: progressHandler)
            }
            
            uploadTask.resume()
        }
    }
    
    // MARK: URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let pct = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        syncQueue.async {
            self.callbacks[task.taskIdentifier]?.progress(pct)
        }
    }
}

// MARK: - PhotoUploader Static Helpers

extension PhotoUploader {
    /// Compute timeout dynamically based on network type *and* file size.
    /// Adds ~1.5 s per MB (capped at +8 s) on top of the base timeout.
    private static func dynamicTimeout(for data: Data) -> TimeInterval {
        let base = PhotoHelper.currentNetworkTimeout()
        let sizeInMB = Double(data.count) / 1_048_576.0
        let extra = min(8.0, sizeInMB * 1.5)
        return base + extra
    }
}

enum PhotoUploadError: Error {
    case imageConversionFailed
    case invalidUrl
    case uploadFailed
    case mismatchedImagesAndUrls
}
