//
//  ShareAcceptanceHandler.swift
//  Clique
//

import CloudKit

struct ShareAcceptanceHandler {
    static func accept(_ metadata: CKShare.Metadata) async {
        let container = CKContainer(identifier: SyncConfiguration.containerIdentifier)
        do {
            try await container.accept(metadata)
            // After accepting, trigger a sync to fetch shared content
            await MainActor.run {
                trigger(.refreshCloudCliques)
            }
        } catch {
            print("Failed to accept CloudKit share: \(error.localizedDescription)")
        }
    }
}
