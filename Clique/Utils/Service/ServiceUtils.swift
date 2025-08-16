//
//  ServiceUtils.swift
//  Clique
//
//  Created by Rod Tavangar on 1/24/25.
//

import Foundation

func fetchNextPage(fetchState: FetchState, page: Int, action: () -> Void) async {
    return
}

@MainActor
func fetchItems<T>(
    page: Int,
    size: Int,
    fetchState: FetchState,
    items: [T],
    action: () async throws -> [T]
) async -> (newPage: Int, newState: FetchState, updatedItems: [T]) {
    var updatedState = fetchState
    var updatedPage = page
    var updatedItems = items
    
    if page == 0 {
        guard items.isEmpty, fetchState != .empty else {
            return (updatedPage, updatedState, updatedItems)
        }
    }
    
    do {
        let newItems = try await action()
        if newItems.isEmpty {
            updatedState = page == 0 ? .empty : .done
        } else {
            updatedItems.append(contentsOf: newItems)
            updatedState = newItems.count < size ? .done : .loaded
            updatedPage += 1
        }
    } catch {
        if error is CancellationError {
            updatedState = .done
        } else {
            updatedState = .failed
        }
    }
    
    return (updatedPage, updatedState, updatedItems)
}
