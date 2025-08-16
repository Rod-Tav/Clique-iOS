//
//  CliqueStore.swift
//  Clique
//
//  Created by Rod Tavangar on 2/24/25.
//

import Foundation

@Observable @MainActor final class CliqueStore {
    var cliques = [String: Clique]() // id to clique
    
    func updateClique(_ clique: Clique, forceUpdateURL: Bool = false) {
        guard var existingClique = cliques[clique.id] else {
            cliques[clique.id] = clique // If clique doesn't exist, add it directly
            return
        }
        
        // Update only fields that have changed
        if existingClique.name != clique.name {
            existingClique.name = clique.name
        }
        if existingClique.bio != clique.bio {
            existingClique.bio = clique.bio
        }
        if forceUpdateURL || shouldUpdatePhotoUrls(existingClique.cliquePic, clique.cliquePic) {
            existingClique.cliquePic = clique.cliquePic
        }
        if forceUpdateURL || shouldUpdatePhotoUrls(existingClique.cliqueBanner, clique.cliqueBanner) {
            existingClique.cliqueBanner = clique.cliqueBanner
        }
        
        if existingClique.numMembers != clique.numMembers {
            existingClique.numMembers = clique.numMembers
        }
        if existingClique.numFlicks != clique.numFlicks {
            existingClique.numFlicks = clique.numFlicks
        }
        
        // Preserve existing leader and relationship if new values are nil
        if clique.leader != nil {
            existingClique.leader = clique.leader
        }
        if clique.relationship != nil {
            existingClique.relationship = clique.relationship
        }
        if clique.memberIDs != nil {
            if existingClique.memberIDs == nil {
                existingClique.memberIDs = clique.memberIDs
            } else if existingClique.memberIDs?.count != clique.memberIDs?.count {
                existingClique.memberIDs = clique.memberIDs
            }
        }
        
        cliques[clique.id] = existingClique
    }
    
    func updateCliques(_ cliques: [Clique], forceUpdateURLs: Bool = false) {
        cliques.forEach({ updateClique($0, forceUpdateURL: forceUpdateURLs) })
    }
    
    func reset() {
        cliques = [String: Clique]()
    }
}
