//
//  SearchHelper.swift
//  Clique
//
//  Created by Rod Tavangar on 2/3/25.
//

import SwiftUI
import AdvancedList

struct SearchHelper {
    static func searchUsers(
        searchText: String,
        query: Binding<String>,
        listState: Binding<ListState>,
        debouncer: Debouncer,
        updateUsers: @escaping (PaginationOperationType) async -> Void
    ) {
//        guard searchText.count >= 3 else {
//            debouncer.cancel()
////            listState.wrappedValue = .items
//            return
//        }
        
        debouncer.debounce {
            Task {
                listState.wrappedValue = .loading
                query.wrappedValue = searchText
                await updateUsers(.refresh)
            }
        }
    }
}

final class Debouncer {
    private var workItem: DispatchWorkItem?
    
    func debounce(delay: TimeInterval = 0.3, action: @escaping () -> Void) {
        workItem?.cancel() // Cancel any pending execution
        
        let workItem = DispatchWorkItem(block: action)
        self.workItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    func cancel() {
        workItem?.cancel()
    }
}
