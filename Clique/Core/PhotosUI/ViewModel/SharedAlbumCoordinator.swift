//
//  SharedAlbumCoordinator.swift
//  Clique
//
//  Minimal ImageDetailCoordinator conformance for shared album photo detail.
//

import SwiftUI
import AdvancedList

@available(iOS 26, *)
@Observable final class SharedAlbumCoordinator: ImageDetailCoordinator {
    // MARK: - Selection State
    var selectedImageId: String?

    // MARK: - Scroll Positions
    var detailScrollPosition: String?
    var detailIndicatorPosition: String?

    // MARK: - Interaction State
    var canInteract: Bool = true

    // MARK: - Pagination State (photos are pre-loaded)
    var listState: ListState = .items
    var paginationState: AdvancedListPaginationState = .idle
    var isScrollAtBottom: Bool = false

    // Protocol default implementations are used for:
    // - didDetailPageChanged
    // - didDetailIndicatorPageChanged
    // - toggleView
    // - resetAnimationProperties
}
