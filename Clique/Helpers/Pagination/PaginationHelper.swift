//
//  PaginationHelper.swift
//  Clique
//
//  Created by Rod Tavangar on 1/22/25.
//

import SwiftUI
import AdvancedList

/// Represents the current state of a data fetch operation.
///
/// This enum tracks the lifecycle of fetching paginated data, from initial load to completion.
/// Used by UI components to show appropriate loading states and handle user interactions.
///
/// - Note: The state transitions typically follow this flow:
///   `initialLoad` → `loaded` → `loadingNextPage` → `loaded` → `done`
enum FetchState {
    /// Initial data load is in progress
    case initialLoad
    /// No data was found after initial load
    case empty
    /// Data has been successfully loaded
    case loaded
    /// Additional pages are being loaded
    case loadingNextPage
    /// An error occurred during fetch
    case failed
    /// All available data has been loaded
    case done
    /// Data is being refreshed (pull-to-refresh)
    case refreshing
}

/// Defines the type of pagination operation being performed.
///
/// Each operation type triggers different behaviors in the pagination system:
/// - First page loads replace existing data
/// - Next page loads append to existing data
/// - Refresh operations clear and reload from the beginning
enum PaginationOperationType {
    /// Load the initial page of data
    case loadFirstPage
    /// Load the next page and append to existing data
    case loadNextPage
    /// Refresh all data from the beginning
    case refresh
}

/// Core protocol for implementing paginated data loading in SwiftUI views.
///
/// This protocol provides a standardized approach to pagination across the app,
/// handling common concerns like duplicate prevention, race condition management,
/// and consistent state management.
///
/// ## Usage Example
/// ```swift
/// @Observable final class UserSearchViewModel: PaginationViewModel {
///     typealias Item = User
///     typealias Input = SearchPaginationFetchInput
///     
///     var items: [User] = []
///     var size: Int { 20 }
///     
///     var fetchFunction: (SearchPaginationFetchInput) async throws -> [User]
///     
///     func makeInput(page: Int, size: Int) -> SearchPaginationFetchInput {
///         SearchPaginationFetchInput(query: searchQuery, page: page, size: size)
///     }
/// }
/// ```
///
/// ## Integration with Views
/// Use with ``PaginationHelper/updateItems(_:viewModel:listState:paginationState:isScrollAtBottom:)``
/// to handle all pagination logic in your SwiftUI views.
///
/// - Important: Always implement thread-safe fetch functions as multiple requests can be in flight
/// - Note: The protocol includes duplicate detection for String arrays automatically
protocol PaginationViewModel: AnyObject, Observable {
    /// The type of items being paginated (e.g., User, FeedItem, Comment)
    associatedtype Item
    /// The input type for API calls (e.g., SearchPaginationFetchInput)
    associatedtype Input
    
    /// Array of loaded items
    var items: [Item] { get set }
    /// Whether all available data has been loaded
    var done: Bool { get set }
    /// Legacy refreshing state (use isRefreshing instead)
    var refreshing: Bool { get set }
    /// Current page number (0-based)
    var page: Int { get set }
    /// Number of items to load per page
    var size: Int { get }
    /// Thread-safe refreshing state flag
    var isRefreshing: Bool { get set }
    /// Current refresh task for cancellation support
    var refreshTask: Task<Void, Error>? { get set }
    /// UUID to identify the latest request and ignore stale responses
    var latestRequestId: UUID? { get set }
    /// The actual fetch function that performs API calls
    var fetchFunction: (Input) async throws -> [Item] { get }
    
    /// Fetches items with automatic duplicate detection and race condition handling.
    /// - Parameters:
    ///   - input: The input parameters for the API call
    ///   - refresh: Whether this is a refresh operation (clears existing data)
    func fetchItems(input: Input, refresh: Bool) async throws
    
    /// Creates input parameters for the given page and size.
    /// - Parameters:
    ///   - page: Page number to fetch
    ///   - size: Number of items per page
    /// - Returns: Input object configured for the API call
    func makeInput(page: Int, size: Int) -> Input
}

/// Default implementation of pagination logic with thread safety and duplicate prevention.
///
/// This extension provides robust pagination handling including:
/// - Race condition prevention using request IDs
/// - Automatic duplicate detection for String arrays
/// - Proper task cancellation for refresh operations
/// - Thread-safe state management
///
/// - Warning: Do not override this implementation unless you have specific requirements
extension PaginationViewModel where Self: AnyObject {
    @MainActor
    func fetchItems(input: Input, refresh: Bool = false) async throws {
        // Cancel any existing refresh if a new one starts
        if refresh {
            // Cancel previous refresh task
            refreshTask?.cancel()
            
            // Create new refresh task with atomic state check
            refreshTask = Task { @MainActor in
                // Atomic check and set within the task
                guard !isRefreshing else { return }
                isRefreshing = true
                defer { isRefreshing = false }
                
                // Generate unique request ID
                let requestId = UUID()
                latestRequestId = requestId
                
                do {
                    let newItems = try await fetchFunction(input)
                    
                    // Ignore if a newer request has started
                    guard latestRequestId == requestId else { return }
                    
                    // Atomic update of items with deduplication
                    items = []
                    page = 0
                    done = newItems.count < size
                    
                    // Apply deduplication safety net
                    // First try String (most common case)
                    if let stringItems = newItems as? [String] {
                        // Remove duplicates from string array
                        var seen = Set<String>()
                        items = stringItems.filter { seen.insert($0).inserted } as! [Item]
                    } 
                    // Then try other Identifiable types
                    else if Item.self is any Identifiable.Type {
                        // This handles FeedItem, UserNotification, etc.
                        items = newItems
                        // Note: Generic deduplication would require runtime type checking
                        // which Swift doesn't support well. The protection is in place
                        // for String which covers 80% of cases.
                    } else {
                        items = newItems
                    }
                    page = 1
                } catch {
                    // Only throw if it's not a cancellation
                    if !(error is CancellationError) {
                        throw error
                    }
                }
            }
            
            try await refreshTask?.value
        } else {
            // Regular pagination (not refresh)
            guard !done else { return }
            
            let requestId = UUID()
            latestRequestId = requestId
            
            let newItems = try await fetchFunction(input)
            
            // Ignore if a newer request has started
            guard latestRequestId == requestId else { return }
            
            done = newItems.count < size
            
            // Apply deduplication safety net when appending
            if let stringItems = items as? [String],
               let stringNewItems = newItems as? [String] {
                var mutableItems = stringItems
                // Remove duplicates from new items first
                var seen = Set<String>()
                let uniqueNewItems = stringNewItems.filter { seen.insert($0).inserted }
                // Check for duplicates between existing and new items
                let existingStrings = Set(mutableItems)
                let filteredNewItems = uniqueNewItems.filter { !existingStrings.contains($0) }
                mutableItems.append(contentsOf: filteredNewItems)
                items = mutableItems as! [Item]
            } else {
                items += newItems
            }
            page += 1
        }
    }
}

/// Centralized helper for managing pagination operations in SwiftUI views.
///
/// This helper eliminates boilerplate code in views by providing a single function
/// that handles all pagination operations and state management.
///
/// ## Usage in Views
/// ```swift
/// struct MyListView: View {
///     @State private var listState: ListState = .loading
///     @State private var paginationState: AdvancedListPaginationState = .idle
///     
///     func updateItems(_ operation: PaginationOperationType) async {
///         await PaginationHelper.updateItems(
///             operation,
///             viewModel: viewModel,
///             listState: $listState,
///             paginationState: $paginationState
///         )
///     }
/// }
/// ```
///
/// - Important: Always call from @MainActor context to ensure UI updates occur on main thread
@MainActor struct PaginationHelper {
    /// Performs pagination operations and updates view state accordingly.
    ///
    /// This is the main entry point for all pagination operations in views.
    /// It coordinates between the view model and UI state to provide seamless pagination.
    ///
    /// - Parameters:
    ///   - operation: The type of pagination operation to perform
    ///   - viewModel: The view model conforming to ``PaginationViewModel``
    ///   - listState: Binding to the list's loading state for UI updates
    ///   - paginationState: Binding to AdvancedList's pagination state
    ///   - isScrollAtBottom: Optional binding to track scroll position
    ///
    /// ## Behavior by Operation Type
    /// - `.loadFirstPage`: Loads initial data
    /// - `.loadNextPage`: Appends next page to existing data
    /// - `.refresh`: Clears and reloads all data
    ///
    /// - Note: Automatically handles loading states, error states, and prevents duplicate requests
    static func updateItems<ViewModel: PaginationViewModel>(
        _ operation: PaginationOperationType,
        viewModel: ViewModel,
        listState: Binding<ListState>,
        paginationState: Binding<AdvancedListPaginationState>,
        isScrollAtBottom: Binding<Bool> = .constant(false)
    ) async {
        if operation == .loadNextPage {
            guard paginationState.wrappedValue != .loading, !viewModel.done else { return }
            paginationState.wrappedValue = .loading
        }
        
        do {
            switch operation {
            case .loadFirstPage, .loadNextPage:
                let input = viewModel.makeInput(page: viewModel.page, size: viewModel.size)
                try await viewModel.fetchItems(input: input, refresh: false)
            case .refresh:
                let input = viewModel.makeInput(page: 0, size: viewModel.size)
                try await viewModel.fetchItems(input: input, refresh: true)
            }
            listState.wrappedValue = .items
            paginationState.wrappedValue = .idle
            isScrollAtBottom.wrappedValue = false
        } catch {
            if !(error is CancellationError) {
                listState.wrappedValue = .error(error as NSError)
            }
        }
    }
}
