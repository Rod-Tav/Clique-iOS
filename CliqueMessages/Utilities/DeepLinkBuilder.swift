//
//  DeepLinkBuilder.swift
//  CliqueMessages
//
//  Builds deep link URLs for opening content in the main Clique app.
//

import Foundation

enum DeepLinkBuilder {
    static func flickURL(flickId: String) -> URL {
        URL(string: "clique://flick/\(flickId)?src=imessage")!
    }

    static func collectionURL(cliqueId: String, collectionId: String) -> URL {
        URL(string: "clique://clique/\(cliqueId)/collection/\(collectionId)?src=imessage")!
    }

    static func cliqueURL(cliqueId: String) -> URL {
        URL(string: "clique://clique/\(cliqueId)?src=imessage")!
    }
}
