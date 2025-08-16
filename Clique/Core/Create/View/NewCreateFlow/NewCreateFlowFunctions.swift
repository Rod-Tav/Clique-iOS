//
//  NewCreateFlowFunctions.swift
//  Clique
//
//  Created by Rod Tavangar on 8/2/25.
//

import Foundation

extension CameraCreateFlow {
    internal func processSelectedPhotos() async {
        await PhotoProcessingHelper.processSelectedPhotosForUpload(viewModel: viewModel)
    }
}
