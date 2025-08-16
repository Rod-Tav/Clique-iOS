//
//  CollectionCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 12/16/24.
//

import SwiftUI
import AdvancedList

@Observable final class CollectionCoordinator {
    var collectionId: String
//    var collection: ClCollection
//    var images: [CollectionImage]
//    var collectionName: String
    init(collectionId: String) {
//        self.collection = collection
        self.collectionId = collectionId
//        self.images = collection.images
    }
    /// Animation Properties
//    var selectedImage: CollectionImage?
    var selectedImageId: String?
//    var animateView: Bool = false
//    var showDetailView: Bool = false
    /// Scroll Positions
    var detailScrollPosition: String?
    var detailIndicatorPosition: String?
    /// Gesture Properties
//    var offset: CGSize = .zero
    
    var canInteract: Bool = true
    
    var listState: ListState = .loading
    var paginationState: AdvancedListPaginationState = .idle
    var isScrollAtBottom: Bool = false
    
    func didDetailPageChanged(updatedImageId: String) {
//        if let updatedItem = images.first(where: { $0.id == detailScrollPosition }) {
        selectedImageId = updatedImageId
            /// Updating Indicator Position
        withAnimation {
            detailIndicatorPosition = updatedImageId
        }
//        }
    }
    
    func didDetailIndicatorPageChanged(updatedImageId: String) {
//        if let updatedItem = images.first(where: { $0.id == detailIndicatorPosition }) {
        selectedImageId = updatedImageId
            /// Updating Detail Paging View As Well
        detailScrollPosition = updatedImageId
//        }
    }
    
    func toggleView(show: Bool) {
        if show {
            canInteract = false
            detailScrollPosition = selectedImageId
            detailIndicatorPosition = selectedImageId
//            .interpolatingSpring(stiffness: 250, damping: 24, initialVelocity: 5), completionCriteria: .removed)
            // .easeInOut(duration: 0.2), completionCriteria: .removed)
//            withAnimation(.snappy(duration: 0.3, extraBounce: 0), completionCriteria: .logicallyComplete) {
//                animateView = true
//            } completion: {
//                self.showDetailView = true
//            }
        } else {
//            showDetailView = false
            // .interpolatingSpring(stiffness: 270, damping: 28.5, initialVelocity: 12), completionCriteria: .removed)
//            withAnimation(.snappy(duration: 0.3, extraBounce: 0), completionCriteria: .logicallyComplete) {
//                animateView = false
//                offset = .zero
//            } completion: {
//                self.resetAnimationProperties()
//            }
            
//            withAnimation(.easeInOut(duration: 0.2), completionCriteria: .removed) {
//                animateView = false
//                offset = .zero
//            } completion: {
//                self.resetAnimationProperties()
//            }
        }
    }
    
    func resetAnimationProperties() {
        selectedImageId = nil
        detailScrollPosition = nil
        detailIndicatorPosition = nil
        canInteract = true
    }
}
