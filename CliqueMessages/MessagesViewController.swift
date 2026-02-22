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

    // MARK: - Properties

    /// Persistent view model — created once, reused across presentations
    private let viewModel = ExtensionViewModel()

    /// Single hosting controller kept alive for the extension's lifetime
    private var rootHostingController: UIHostingController<ExtensionRootView>?

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)

        // Wire up message handlers
        configureHandlers()

        // Start data loading immediately (fixes gray screen)
        viewModel.willBecomeActive()

        // Present the root view if not already presented
        if rootHostingController == nil {
            presentRootView()
        }
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        viewModel.didResignActive()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        viewModel.updatePresentationStyle(presentationStyle)
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        super.didStartSending(message, conversation: conversation)
        viewModel.didStartSendingMessage(message)
    }

    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        super.didCancelSending(message, conversation: conversation)
        viewModel.didCancelSendingMessage(message)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        viewModel.didReceiveMessage(message)
    }

    // MARK: - Content Presentation

    private func presentRootView() {
        // Check auth — if not authenticated, show auth bridge instead
        guard ExtensionAuthManager.shared.isAuthenticated else {
            presentAuthBridgeView()
            return
        }

        let rootView = ExtensionRootView(viewModel: viewModel) { [weak self] in
            self?.requestPresentationStyle(.expanded)
        }
        let hostingController = UIHostingController(rootView: rootView)
        rootHostingController = hostingController
        addChild(hostingController, to: view)
    }

    private func presentAuthBridgeView() {
        removeAllChildViewControllers()
        let authView = AuthBridgeView()
        let hostingController = UIHostingController(rootView: authView)
        addChild(hostingController, to: view)
    }

    // MARK: - Handler Configuration

    private func configureHandlers() {
        viewModel.sendMessageHandler = { [weak self] message in
            self?.activeConversation?.insert(message) { error in
                if let error {
                    print("MessagesViewController: Failed to insert message: \(error)")
                }
            }
        }

        viewModel.dismissHandler = { [weak self] in
            self?.requestPresentationStyle(.compact)
        }

        viewModel.openURLHandler = { [weak self] url in
            self?.extensionContext?.open(url)
        }

        // Closure for CloudCliqueComposerView to insert messages
        viewModel.insertCloudCliqueMessageHandler = { [weak self] message in
            guard let conversation = self?.activeConversation else { return }
            conversation.insert(message) { error in
                if error == nil {
                    self?.requestPresentationStyle(.compact)
                }
            }
        }

        // Closure to request expansion (e.g. from compact "+" button)
        viewModel.requestExpansionHandler = { [weak self] in
            self?.requestPresentationStyle(.expanded)
        }
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
        rootHostingController = nil
    }
}
