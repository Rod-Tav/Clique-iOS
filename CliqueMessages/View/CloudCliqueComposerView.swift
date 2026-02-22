//
//  CloudCliqueComposerView.swift
//  CliqueMessages
//
//  SwiftUI view for creating a Cloud Clique and sharing it in an iMessage conversation.
//

import SwiftUI
import Messages
import CloudKit

struct CloudCliqueComposerView: View {
    @State private var cliqueName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    var conversation: MSConversation?
    var onInsertMessage: (MSMessage) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            header
            nameInput
            if let errorMessage {
                errorBanner(errorMessage)
            }
            createButton
            Spacer()
        }
        .padding(20)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.cliquePink)
            Text("New Cloud Clique")
                .font(.title2.weight(.bold))
            Text("Create a shared photo group with your friends")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var nameInput: some View {
        TextField("Clique name", text: $cliqueName)
            .textFieldStyle(.roundedBorder)
            .font(.body)
            .disabled(isCreating)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
    }

    private var createButton: some View {
        Button(action: {
            Task { await createAndShare() }
        }) {
            Group {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Create & Share")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canCreate ? Color.cliquePink : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canCreate)
    }

    private var canCreate: Bool {
        !cliqueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    // MARK: - Actions

    private func createAndShare() async {
        let trimmedName = cliqueName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        do {
            // 1. Create the clique via Kotlin backend
            let cliqueId = try await ExtensionAPIClient.shared.createClique(name: trimmedName)

            // 2. Create CloudKit shared zone and get the CKShare
            let share = try await CloudKitSharingService.shared.createSharedZone(cliqueId: cliqueId)

            guard let shareURL = share.url else {
                errorMessage = "Failed to generate share link. Please try again."
                isCreating = false
                return
            }

            // 3. Register the CloudKit zone with rod-sandbox
            let zoneId = SyncConfiguration.zoneName(for: cliqueId)
            try await ExtensionAPIClient.shared.setCloudKitZone(
                cliqueId: cliqueId,
                zoneId: zoneId,
                shareUrl: shareURL.absoluteString
            )

            // 4. Build and insert the iMessage
            let message = CliqueMessageLayout.createMessage(
                cliqueName: trimmedName,
                shareURL: shareURL
            )
            onInsertMessage(message)

        } catch ExtensionAPIClient.ExtensionError.notAuthenticated {
            errorMessage = "Please open the Clique app and sign in first."
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isCreating = false
    }
}
