//
//  SyncConfiguration.swift
//  CliqueMessages
//
//  Configuration for CloudKit zone naming conventions.
//

import Foundation

enum SyncConfiguration {
    static func zoneName(for cliqueId: String) -> String {
        "clique-\(cliqueId)"
    }
}
