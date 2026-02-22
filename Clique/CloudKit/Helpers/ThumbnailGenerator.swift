import Photos
import UIKit

/// Generates compressed thumbnail images for CloudKit sync.
struct ThumbnailGenerator {

    /// Generates a JPEG thumbnail from a UIImage, resized to fit within `maxDimension`.
    static func generate(from image: UIImage, maxDimension: CGFloat = 800) -> Data? {
        let size = image.size
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        // Only downscale, never upscale
        guard scale < 1.0 else {
            return image.jpegData(compressionQuality: 0.6)
        }

        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }

    /// Generates a JPEG thumbnail from a PHAsset using the Photos framework.
    static func generate(from asset: PHAsset) async -> Data? {
        let targetSize = CGSize(width: 800, height: 800)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }

                if let image {
                    continuation.resume(returning: image.jpegData(compressionQuality: 0.6))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
