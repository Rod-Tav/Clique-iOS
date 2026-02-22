//
//  MessagesViewController.swift
//  CliqueMessages
//
//  Main entry point for the Clique iMessage extension.
//
//  NOTE: The CliqueMessages target must be added manually in Xcode:
//  1. File > New > Target > iMessage Extension
//  2. Set Bundle Identifier to com.cliquellc.clique.messages
//  3. Add App Group "group.com.cliquellc.clique" in Signing & Capabilities
//  4. Add CloudKit capability with container "iCloud.com.cliquellc.clique"
//  5. Point the target at this directory's files
//

import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    private var composerHostingController: UIHostingController<CloudCliqueComposerView>?

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        presentContent(for: presentationStyle, conversation: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        presentContent(for: presentationStyle, conversation: activeConversation)
    }

    // MARK: - Content Presentation

    private func presentContent(for style: MSMessagesAppPresentationStyle, conversation: MSConversation?) {
        removeAllChildViewControllers()

        guard ExtensionAuthManager.shared.isAuthenticated else {
            presentAuthBridgeView()
            return
        }

        switch style {
        case .compact:
            presentCompactView()
        case .expanded:
            presentComposerView(conversation: conversation)
        case .transcript:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Compact View

    private func presentCompactView() {
        let compactView = CompactLauncherView { [weak self] in
            self?.requestPresentationStyle(.expanded)
        }
        let hostingController = UIHostingController(rootView: compactView)
        addChild(hostingController, to: view)
    }

    // MARK: - Expanded View (Composer)

    private func presentComposerView(conversation: MSConversation?) {
        let composerView = CloudCliqueComposerView(
            conversation: conversation
        ) { [weak self] message in
            guard let conversation = self?.activeConversation else { return }
            conversation.insert(message) { error in
                if error == nil {
                    self?.requestPresentationStyle(.compact)
                }
            }
        } onDismiss: { [weak self] in
            self?.requestPresentationStyle(.compact)
        }

        let hostingController = UIHostingController(rootView: composerView)
        composerHostingController = hostingController
        addChild(hostingController, to: view)
    }

    // MARK: - Auth Bridge

    private func presentAuthBridgeView() {
        let authView = AuthBridgeView()
        let hostingController = UIHostingController(rootView: authView)
        addChild(hostingController, to: view)
    }

    // MARK: - Child View Controller Helpers

    private func addChild(_ childController: UIViewController, to containerView: UIView) {
        addChild(childController)
        childController.view.frame = containerView.bounds
        childController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(childController.view)
        childController.didMove(toParent: self)
    }

    private func removeAllChildViewControllers() {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        composerHostingController = nil
    }
}

// MARK: - Compact Launcher View

/// Small view shown in compact mode with a button to expand into the composer.
private struct CompactLauncherView: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Create Cloud Clique")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.cliquePink)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
