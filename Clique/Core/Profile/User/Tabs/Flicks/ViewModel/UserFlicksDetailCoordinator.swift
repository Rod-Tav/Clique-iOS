//
//  UserFlicksDetailCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 12/9/25.
//

import SwiftUI
import AdvancedList

@Observable final class UserFlicksDetailCoordinator: ImageDetailCoordinator {
    // MARK: - Selection State
    var selectedImageId: String?

    // MARK: - Scroll Positions
    var detailScrollPosition: String?
    var detailIndicatorPosition: String?

    // MARK: - Interaction State
    var canInteract: Bool = true

    // MARK: - Pagination State (delegates to viewModel in UserFlicksView)
    var listState: ListState = .items
    var paginationState: AdvancedListPaginationState = .idle
    var isScrollAtBottom: Bool = false

    // MARK: - Initialization
    init() {}

    // Protocol default implementations are used for:
    // - didDetailPageChanged
    // - didDetailIndicatorPageChanged
    // - toggleView
    // - resetAnimationProperties
}
