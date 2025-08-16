////
////  UICoordinator.swift
////  Clique
////
////  Created by Rod Tavangar on 6/30/24.
////
//
//import SwiftUI
//
//@Observable
//class UICoordinator {
//    var collection: ClCollection = ClCollection.MOCK_COLLECTIONS[0]
//    var items: [CollectionImage]
//    init(collection: ClCollection) {
//        self.collection = collection
//        self.items = collection.images
//    }
//    /// Animation Properties
//    var viewItem: CollectionImage?
//    var animateView: Bool = false
//    var showDetailView: Bool = false
//    var showDetailBars: Bool = false
//    var hideDetailBars: Bool = false
//    var earlyClose: Bool = false
//    /// Scroll Positions
//    var viewItemPosition: Int?
//    var detailIndicatorPosition: String?
//    /// Gesture Properties
//    var offset: CGSize = .zero
//    var opacity: CGFloat = 1
//    var dragProgress: CGFloat = 0
//    var canTap: Bool = true // TODO: workaround for tapping immediately after close
//    
//    func didDetailPageChanged() {
//        // find item with new index
//        if let updatedItem = items.first(where: { $0.index == viewItemPosition }) {
//            viewItem = updatedItem
//            /// Updating Indicator Position
//            withAnimation(.easeInOut(duration: 0.1)) {
//                detailIndicatorPosition = updatedItem.id
//            }
//        }
//    }
//    
//    func didDetailIndicatorPageChanged() {
//        if let updatedItem = items.first(where: { $0.id == detailIndicatorPosition }) {
//            viewItem = updatedItem
//            /// Updating Detail Paging View As Well
//            viewItemPosition = updatedItem.index
//        }
//    }
//    
//    func toggleView(show: Bool) {
//        if show {
//            viewItemPosition = viewItem?.index
//            detailIndicatorPosition = viewItem?.id
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.75), completionCriteria: .logicallyComplete) {
////            withAnimation(.easeInOut(duration: 0.2), completionCriteria: .removed) {
//                animateView = true
//                withAnimation(.easeInOut(duration: 0.1)) {
//                    showDetailBars = true
//                }
//            } completion: {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
//                    if !self.earlyClose {
//                        self.showDetailView = true
//                    }
//                }
//            }
//        } else {
//            canTap = false
//            showDetailView = false
//            withAnimation(.easeInOut(duration: 0.2)) {
//                hideDetailBars = true
//            }
//            withAnimation(.easeInOut(duration: 0.2), completionCriteria: .removed) {
//                animateView = false
//                offset = .zero
//                opacity = 0
//            } completion: {
//                self.resetAnimationProperties()
//            }
//        }
//    }
//    
//    func resetAnimationProperties() {
//        // for some reason, tapping an image immediately after closing bricks the view
//        // if tab is switched then when you come back the image opens
//        // this wait fixes but is a hack
//        // TODO: find and fix why tapping an image immediately after closing doesn't work, get rid of this asyncAfter
////        DispatchQueue.main.asyncAfter(deadline: .now()) {
//            viewItem = nil
////        }
//        viewItemPosition = nil
//        offset = .zero
//        dragProgress = 0
//        detailIndicatorPosition = nil
//        showDetailBars = false
//        hideDetailBars = false
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            self.canTap = true
////            opacity = 0
//        }
//    }
//}
