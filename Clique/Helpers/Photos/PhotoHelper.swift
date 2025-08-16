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

/// Prepares image data and compression variants for upload
func prepareUIImage(_ uiImage: UIImage?) -> (photoData: Components.Schemas.PhotoDataNoPath, imageVariants: (high: PreparedImageVariant, medium: PreparedImageVariant, low: PreparedImageVariant))? {
    guard let uiImage else { return nil }
    
    /// Helper function to generate UploadPhotoParams and keep Data
    func createUploadPhotoParams(from image: UIImage, targetWidth: CGFloat?, quality: CGFloat) -> PreparedImageVariant? {
        // If targetWidth is provided, resize; otherwise use original
        let processedImage: UIImage
        if let width = targetWidth {
            guard let resized = image.resized(toWidth: width) else { return nil }
            processedImage = resized
        } else {
            processedImage = image
        }
        
        // Compress to JPEG
        guard let imageData = processedImage.jpegData(compressionQuality: quality) else { return nil }
        
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
    
    // High: original resolution, medium and low are resized
    guard let high = createUploadPhotoParams(from: uiImage, targetWidth: nil, quality: 0.3),
          let medium = createUploadPhotoParams(from: uiImage, targetWidth: 600, quality: 0.1),
          let low = createUploadPhotoParams(from: uiImage, targetWidth: 200, quality: 0.2) else {
        return nil
    }
    
    // Optional debug prints
    print("High Quality: \(high.params.contentLength ?? 0), \(high.params.contentMd5 ?? "")")
    print("Medium Quality: \(medium.params.contentLength ?? 0), \(medium.params.contentMd5 ?? "")")
    print("Low Quality: \(low.params.contentLength ?? 0), \(low.params.contentMd5 ?? "")")
    
    let photoData = Components.Schemas.PhotoDataNoPath(
        basePhoto: high.params,
        medQualityPhoto: medium.params,
        lowQualityPhoto: low.params
    )
    
    return (photoData, (high: high, medium: medium, low: low))
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
    static func createPhotoDatePairs(images: [UIImage], dates: [Date]) -> [Components.Schemas.PhotoDatePair] {
        return zip(images, dates).map { image, date in
            let photoDataNoPath = prepareUIImage(image)
            return mapToPhotoDatePair(photo: photoDataNoPath?.photoData, date: date)
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
    
    static func uploadImages(
        preparedImages: [(high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)],
        urls: [(high: String?, med: String?, low: String?)],
        onProgress: @escaping (Int, Int) -> Void,
        failedUpload: @escaping (Int, ImageQuality) -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) async {
        let totalUploads = urls.flatMap { [$0.high, $0.med, $0.low] }.compactMap { $0 }.count
        let counter = UploadCounter()
        
        let semaphore = AsyncSemaphore(value: 6)
        
        let failedTracker = FailedVariantTracker()
        
        await withTaskGroup(of: Void.self) { taskGroup in
            
            func addUploadTask(data: Data, url: String, index: Int, quality: ImageQuality) {
                taskGroup.addTask {
                    await semaphore.wait()
                    
                    do {
                        try await uploadImageDataWithRetry(data, to: url)
                        let newCount = await counter.increment()
                        await MainActor.run {
                            onProgress(newCount, totalUploads)
                        }
                    } catch {
                        await failedTracker.insert(index, quality: quality)
                        failedUpload(index, quality)
                        print("❌ Upload failed for \(quality.rawValue.uppercased()) quality at index \(index): \(error.localizedDescription)")
                    }
                    
                    await semaphore.signal()
                }
            }
            
            for (index, imageVariants) in preparedImages.enumerated() {
                let (highData, medData, lowData) = (imageVariants.high, imageVariants.med, imageVariants.low)
                let (highUrl, medUrl, lowUrl) = urls[index]
                
                if let highUrl {
                    addUploadTask(data: highData.data, url: highUrl, index: index, quality: .high)
                }
                if let medUrl {
                    addUploadTask(data: medData.data, url: medUrl, index: index, quality: .medium)
                }
                if let lowUrl {
                    addUploadTask(data: lowData.data, url: lowUrl, index: index, quality: .low)
                }
            }
        }
        
        let allSucceeded = await failedTracker.isEmpty()
        await MainActor.run {
            onCompletion(allSucceeded)
        }
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
            
            let maxAttempts = 3
            var delay: TimeInterval = 0.5
            var lastError: Error?
            
            for attempt in 1...maxAttempts {
                do {
                    let timeout = Self.dynamicTimeout(for: data)
                    
                    try await self.withTimeout(seconds: timeout) {
                        try await self.performSingleUpload(
                            request: request,
                            data: data,
                            progressHandler: progressHandler
                        )
                    }
                    
                    completion(.success(()))          // ✅ success
                    return
                } catch {
                    lastError = error
                    print("⚠️ Upload attempt \(attempt) failed: \(error.localizedDescription)")
                    
                    guard attempt < maxAttempts else { break }
                    
                    let jitter = Double.random(in: 0.75...1.25)
                    let sleepTime = delay * jitter
                    print("⏳ Retrying upload attempt \(attempt + 1) in \(String(format: "%.2f", sleepTime)) seconds")
                    try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                    delay *= 2
                }
            }
            
            completion(.failure(lastError ?? URLError(.timedOut)))
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
                } else if let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode) {
                    cont.resume(returning: ())
                } else {
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
