//
//  UploadProgressViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 1/29/25.
//

import SwiftUI

@Observable
class UploadProgressViewModel {
    var uploadProgress: [String: Double] = [:]

    func updateProgress(for photoId: String, progress: Double) {
        uploadProgress[photoId] = progress
    }
}
