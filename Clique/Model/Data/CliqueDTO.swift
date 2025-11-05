//
//  CliqueDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 1/18/25.
//

import SwiftUI

func mapToClique(_ clique: Components.Schemas.Clique) -> Clique {
    if clique.dateCreated == nil {
//        print(clique)
    }
    return Clique(
        id: clique.cliqueId!,
        name: clique.name!,
        creation: convertToDate(clique.dateCreated),
        bio: clique.bio!,
        cliquePic: clique.cliqueProfilePic == nil ? nil : mapToMediaUrls(clique.cliqueProfilePic!),
        cliqueBanner: clique.cliqueBanner == nil ? nil : mapToMediaUrls(clique.cliqueBanner!),
        numMembers: clique.memberCount ?? 0,
        numFlicks: clique.flickCount ?? 0
    )
}

func mapToClique(_ data: Components.Schemas.CreateCliqueResponseBody) -> Clique {
    return mapToClique(data.clique!)
}

func mapToClique(_ data: Components.Schemas.GetCliqueResponseBody) -> Clique {
    return mapToClique(data.clique!)
}

func mapToCliques(_ data: Components.Schemas.GetCliquesResponseBody) -> [Clique] {
    return data.cliques!.map { mapToClique($0) }
}
