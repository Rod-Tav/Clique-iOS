//
//  SelectedPhotosViewFunctions.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import Foundation
import Photos
import Toasts

/// Delay after dismissing views before starting upload (0.1 seconds)
/// Ensures smooth dismissal animation completion before navigation changes
private let dismissalDelayMilliseconds = Duration.milliseconds(100)

extension SelectedPhotosView {
    internal func removeCurrentPhoto() {
        guard !selectedAssetsArray.isEmpty && currentIndex < selectedAssetsArray.count else { return }

        let assetToRemove = selectedAssetsArray[currentIndex]
        removePhoto(assetToRemove)
    }

    internal func removePhoto(_ asset: PHAsset) {
        guard let index = selectedAssetsArray.firstIndex(of: asset) else { return }

        viewModel.removeAsset(asset)

        // Clean up zoom states
        zoomScales.removeValue(forKey: asset)
        dragOffsets.removeValue(forKey: asset)

        // Adjust current index if needed
        if selectedAssetsArray.isEmpty {
            dismiss()
        } else if index >= selectedAssetsArray.count {
            // If we removed the last item, go to the new last item
            currentIndex = max(0, selectedAssetsArray.count - 1)
            scrollPosition = selectedAssetsArray[currentIndex]
        } else {
            // Stay at the same index (next photo slides in)
            currentIndex = min(index, selectedAssetsArray.count - 1)
            if !selectedAssetsArray.isEmpty {
                scrollPosition = selectedAssetsArray[currentIndex]
            }
        }
    }

    /// Handle upload button tap - shows picker or uploads
    internal func handleUpload() {
        if viewModel.selectedCollectionId == nil {
            activeSheet = .chooseCollection
        } else {
            Task {
                await uploadToExistingCollection()
            }
        }
    }

    /// Process PHAssets → UIImages and prepare for upload
    private func processPhotos() async {
        isProcessing = true

        let assetsToProcess = viewModel.orderedSelectedAssets
        totalCount = assetsToProcess.count
        processedCount = 0
        var hasErrors = false

        await PhotoProcessingHelper.processAssets(
            assets: assetsToProcess,
            viewModel: viewModel,
            clearExistingData: true,
            onProgress: { processed, total in
                self.processedCount = processed
                self.totalCount = total
                self.processingProgress = total > 0 ? Double(processed) / Double(total) : 0.0
            },
            onError: { error in
                hasErrors = true
                print("Error processing asset: \(error)")
            },
            onComplete: {}
        )

        await PhotoProcessingHelper.processSelectedPhotosForUpload(viewModel: viewModel)

        await MainActor.run {
            isProcessing = false

            // Show error toast if any photos failed to process
            if hasErrors {
                presentToast(Toasts.imageOptimizationFailed)
            }
        }
    }

    /// Process photos, dismiss view, and start upload
    ///
    /// Used for both existing collection uploads (from handleUpload) and new collection creation
    /// (from NewCollectionDetailsView via onChange). The logic is identical for both flows:
    /// 1. Process photos if needed (PHAssets → UIImages → upload variants)
    /// 2. Dismiss SelectedPhotosView fullScreenCover
    /// 3. Wait for dismissal animation to complete
    /// 4. Start upload with already-processed data
    private func processAndUpload() async {
        // Process photos if not already done
        if viewModel.selectedImages.isEmpty && !viewModel.selectedAssets.isEmpty {
            await processPhotos()
        }

        // Dismiss SelectedPhotosView (the fullScreenCover)
        await MainActor.run {
            dismiss()
        }

        // Wait for dismiss animation to complete
        try? await Task.sleep(for: dismissalDelayMilliseconds)

        // Start upload with skipProcessing since already done
        await MainActor.run {
            viewModel.startUpload(userStore, tabViewCoordinator, skipProcessing: true)
        }
    }

    /// Upload to existing collection - convenience wrapper
    private func uploadToExistingCollection() async {
        await processAndUpload()
    }

    /// Process photos and upload for new collection - convenience wrapper for onChange trigger
    internal func processPhotosAndUploadForNewCollection() async {
        await processAndUpload()
    }

    /// Determines if a photo at the given index should be loaded.
    ///
    /// Implements smart preloading: loads current photo + 2 adjacent photos on each side
    /// to enable smooth swiping without overwhelming the Photos framework.
    ///
    /// - Parameter index: The index of the photo to check
    /// - Returns: `true` if the photo should be loaded (within distance of 2 from current index)
    internal func shouldLoadPhoto(at index: Int) -> Bool {
        let distance = abs(index - currentIndex)
        return distance <= 2  // Load current + 2 on each side (5 photos total max)
    }
}
