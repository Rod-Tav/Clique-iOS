//
//  ProcessingOverlay.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI

/// Appears while processing photos from device in custom picker
struct ProcessingOverlay: View {
    var message: String = "Processing photos..."
    var progress: Double? = nil
    var processedCount: Int = 0
    var totalCount: Int = 0
    
    private var progressMessage: String {
        if totalCount > 0 {
            return "Processing \(processedCount) of \(totalCount) photos..."
        }
        return message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                if let progress = progress, totalCount > 0 {
                    // Determinate progress bar
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .width(200)
                } else {
                    // Indeterminate spinner
                    ProgressView()
                }
                
                Text(progressMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .roundCorners(12)
            .shadow(radius: 10)
        }
    }
}
