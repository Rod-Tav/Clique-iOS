//
//  CliqueMessageLayout.swift
//  CliqueMessages
//
//  Builds MSMessage objects for Cloud Clique invitations in iMessage.
//

import Messages
import UIKit

struct CliqueMessageLayout {

    /// Creates an MSMessage configured as a Cloud Clique invitation.
    /// - Parameters:
    ///   - cliqueName: Display name of the clique.
    ///   - shareURL: The CloudKit share URL recipients use to join.
    ///   - coverImage: Optional cover image shown in the message bubble.
    /// - Returns: A fully configured MSMessage ready for insertion.
    static func createMessage(
        cliqueName: String,
        shareURL: URL,
        coverImage: UIImage? = nil
    ) -> MSMessage {
        let message = MSMessage()
        let layout = MSMessageTemplateLayout()

        layout.caption = "Join \(cliqueName)"
        layout.subcaption = "Cloud Clique Invitation"

        if let image = coverImage {
            layout.image = image
        }

        message.layout = layout
        message.url = shareURL
        message.summaryText = "Invited you to \(cliqueName)"

        return message
    }
}
