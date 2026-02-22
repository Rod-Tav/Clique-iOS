//
//  CloudCliquesStore.swift
//  Clique
//
//  Observable store that holds fetched Cloud Clique metadata.
//

import Foundation

@available(iOS 26, *)
@Observable class CloudCliquesStore {
    var cliques: [CloudCliqueInfo] = []
    var isLoaded: Bool = false

    func loadCliques() async {
        guard !isLoaded else { return }
        do {
            let fetched = try await CloudCliqueService.fetchCloudCliques()
            await MainActor.run {
                cliques = fetched
                isLoaded = true
            }
        } catch {
            print("[CloudCliquesStore] Failed to load: \(error)")
            await MainActor.run { isLoaded = true }
        }
    }

    func cliqueForAlbum(title: String) -> CloudCliqueInfo? {
        cliques.first { $0.linkedAlbumTitle == title }
    }

    func unlinkedCliques() -> [CloudCliqueInfo] {
        cliques.filter { $0.linkedAlbumTitle == nil }
    }

    func refresh() async {
        isLoaded = false
        await loadCliques()
    }
}
