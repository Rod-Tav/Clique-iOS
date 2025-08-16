//
//  PhotoPickerContainer.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI
import Photos
import Toasts

struct PhotoPickerContainer<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) var presentToast
    
    @Environment(TabViewCoordinator.self) var tabViewCoordinator
    @Environment(CreateViewModel.self) var viewModel
    
    @State private var context = PhotoPickerContext()
    
    let configuration: PhotoPickerConfiguration = PhotoPickerConfiguration()
    let content: (PhotoPickerContext) -> Content
    
    var body: some View {
        ZStack {
            content(context)
                .environment(context)
            
            if context.isProcessing {
                ProcessingOverlay(
                    progress: context.processingProgress,
                    processedCount: context.processedCount,
                    totalCount: context.totalCount
                )
            }
        }
    }
}
