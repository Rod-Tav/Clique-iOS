//
//  NotificationsPaginationViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 5/24/25.
//

import Foundation

@Observable final class NotificationsPaginationViewModel: PaginationViewModel {
    typealias Item = UserNotification // notification id
    typealias Input = EmptyPaginationFetchInput
    
    var items: [UserNotification] = []
    
    var page: Int = 0
    var size: Int { 25 }
    
    var done: Bool = false
    var refreshing: Bool = false
    
    // New properties for thread-safe refresh
    var isRefreshing: Bool = false
    var refreshTask: Task<Void, Error>?
    var latestRequestId: UUID?
    
    var fetchFunction: (EmptyPaginationFetchInput) async throws -> [UserNotification]
    
    init(_ userStore: UserStore, _ cliqueStore: CliqueStore, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.fetchFunction = { input in
            let notis = try await NotificationService.getUserNotifications(.init(query: .init(page: input.page, size: input.size)))
            
            await userStore.updateUsers(notis.compactMap { $0.user })
            await cliqueStore.updateCliques(notis.compactMap { $0.clique })
            await collectionStore.updateCollections(notis.compactMap { $0.collection }, collectionImageStore)
            await collectionImageStore.updateImages(notis.compactMap { $0.collectionImage })
            
            return notis
        }
    }
    
    func makeInput(page: Int, size: Int) -> EmptyPaginationFetchInput {
        return EmptyPaginationFetchInput(page: page, size: size)
    }
}
