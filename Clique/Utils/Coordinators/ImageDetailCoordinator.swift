//
//  ImageDetailCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 12/9/25.
//

import SwiftUI
import AdvancedList

/// Protocol defining shared interface for grid-to-detail coordination
/// Allows CollectionDetailView and similar views to work with different data sources
protocol ImageDetailCoordinator: AnyObject, Observable {
    // MARK: - Selection State
    var selectedImageId: String? { get set }

    // MARK: - Scroll Positions
    var detailScrollPosition: String? { get set }
    var detailIndicatorPosition: String? { get set }

    // MARK: - Interaction State
    var canInteract: Bool { get set }

    // MARK: - Pagination State
    var listState: ListState { get set }
    var paginationState: AdvancedListPaginationState { get set }
    var isScrollAtBottom: Bool { get set }

    // MARK: - Synchronization Methods
    func didDetailPageChanged(updatedImageId: String)
    func didDetailIndicatorPageChanged(updatedImageId: String)
    func toggleView(show: Bool)
    func resetAnimationProperties()
}

/// Default implementations for synchronization methods
extension ImageDetailCoordinator {
    func didDetailPageChanged(updatedImageId: String) {
        selectedImageId = updatedImageId
        withAnimation {
            detailIndicatorPosition = updatedImageId
        }
    }

    func didDetailIndicatorPageChanged(updatedImageId: String) {
        selectedImageId = updatedImageId
        detailScrollPosition = updatedImageId
    }

    func toggleView(show: Bool) {
        if show {
            canInteract = false
            detailScrollPosition = selectedImageId
            detailIndicatorPosition = selectedImageId
        }
    }

    func resetAnimationProperties() {
        selectedImageId = nil
        detailScrollPosition = nil
        detailIndicatorPosition = nil
        canInteract = true
    }
}

// MARK: - Grid Sync ScrollView

/// A ScrollView wrapper that syncs scroll position with an ImageDetailCoordinator.
/// When the detail carousel changes selectedImageId, the grid scrolls to match.
struct GridSyncScrollView<Coordinator: ImageDetailCoordinator, Content: View>: View {
    let coordinator: Coordinator
    var anchor: UnitPoint = .center
    var scrollToId: Binding<String?>?
    var onWillScroll: ((String) -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                content()
            }
            .onChange(of: coordinator.selectedImageId) { oldValue, newValue in
                guard oldValue != nil, let newValue else { return }
                onWillScroll?(newValue)
                reader.scrollTo(newValue, anchor: anchor)
            }
            .onChange(of: scrollToId?.wrappedValue) { _, newValue in
                guard let newValue else { return }
                withAnimation {
                    reader.scrollTo(newValue, anchor: .top)
                }
                scrollToId?.wrappedValue = nil
            }
        }
    }
}

// MARK: - Grid Sync View Modifier

/// A view modifier that adds grid-to-detail scroll synchronization to any ScrollView.
/// Use this when you need custom ScrollView configuration beyond what GridSyncScrollView provides.
struct GridSyncModifier<Coordinator: ImageDetailCoordinator>: ViewModifier {
    let coordinator: Coordinator
    var anchor: UnitPoint = .center
    var onWillScroll: ((String) -> Void)?

    func body(content: Content) -> some View {
        ScrollViewReader { reader in
            content
                .onChange(of: coordinator.selectedImageId) { oldValue, newValue in
                    guard oldValue != nil, let newValue else { return }
                    onWillScroll?(newValue)
                    reader.scrollTo(newValue, anchor: anchor)
                }
        }
    }
}

extension View {
    /// Adds grid-to-detail scroll synchronization.
    /// Wraps the view in a ScrollViewReader and scrolls to the selected image when it changes.
    func gridSync<Coordinator: ImageDetailCoordinator>(
        coordinator: Coordinator,
        anchor: UnitPoint = .center,
        onWillScroll: ((String) -> Void)? = nil
    ) -> some View {
        modifier(GridSyncModifier(coordinator: coordinator, anchor: anchor, onWillScroll: onWillScroll))
    }
}
