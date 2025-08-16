//
//  UIImageDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 1/29/25.
//

import SwiftUI
import CryptoKit

struct PreparedImageVariant {
    let data: Data
    let params: Components.Schemas.UploadPhotoParams
}

extension UIImage {
    /// Resize to a target width while maintaining aspect ratio
    func resized(toWidth width: CGFloat) -> UIImage? {
        let scale = width / self.size.width
        let height = self.size.height * scale
        let size = CGSize(width: width, height: height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
