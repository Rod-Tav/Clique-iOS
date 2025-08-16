//
//  CliqueInviteDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 2/5/25.
//

import Foundation

struct CliqueInvite: Identifiable {
    var id: String
    var fromUser: User
    var clique: Clique
}

func mapToCliqueInvite(_ invite: Components.Schemas.CliqueInvite) -> CliqueInvite {
    return CliqueInvite(id: invite.cliqueInviteId!, fromUser: mapToUser(invite.fromUser!), clique: mapToClique(invite.clique!))
}
