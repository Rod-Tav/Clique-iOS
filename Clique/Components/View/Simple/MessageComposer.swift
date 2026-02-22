//
//  MessageComposer.swift
//  Clique
//
//  UIViewControllerRepresentable wrapper for MFMessageComposeViewController.
//

import SwiftUI
import MessageUI

struct CliqueMessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: CliqueMessageComposer
        init(_ parent: CliqueMessageComposer) { self.parent = parent }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}
