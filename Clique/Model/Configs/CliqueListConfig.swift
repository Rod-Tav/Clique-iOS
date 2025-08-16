//
//  CliqueListConfig.swift
//  Clique
//
//  Created by Rod Tavangar on 6/16/24.
//

import Foundation

/// Different types of a list of cliques
enum CliqueListConfig: Hashable {
    case search
    case cliques(uid: String) // cliques of user uid
    case cliqueHub
    
    var navigationTitle: String {
        switch self {
        case .search:
            return "Search"
        case .cliques:
            return "Members"
        case .cliqueHub:
            return "Clique Hub" // TODO: this whole thing gets deleted?
        }
    }
}
