//
//  CliquePickerSheet.swift
//  Clique
//
//  Sheet for linking a shared album to an unlinked Cloud Clique.
//

import SwiftUI

@available(iOS 26, *)
struct CliquePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(CloudCliquesStore.self) var cloudCliquesStore

    let albumTitle: String
    var onLinked: (() -> Void)? = nil

    @State var isLinking: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if cloudCliquesStore.unlinkedCliques().isEmpty && cloudCliquesStore.cliqueForAlbum(title: albumTitle) == nil {
                    emptyState
                } else {
                    ForEach(cloudCliquesStore.unlinkedCliques(), id: \.cliqueId) { clique in
                        Button {
                            linkClique(clique)
                        } label: {
                            cliqueRow(clique)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLinking)
                    }
                }

                if let linked = cloudCliquesStore.cliqueForAlbum(title: albumTitle) {
                    Section("Currently Linked") {
                        HStack {
                            cliqueRow(linked)
                            Spacer()
                            Button("Unlink") {
                                unlinkClique(linked)
                            }
                            .foregroundStyle(.red)
                            .disabled(isLinking)
                        }
                    }
                }
            }
            .navigationTitle("Link to Clique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func cliqueRow(_ clique: CloudCliqueInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.theme.buttonCTA)

            VStack(alignment: .leading, spacing: 2) {
                Text(clique.cliqueName)
                    .font(.subheadline.weight(.medium))
                    .textPrimary()

                Text("\(clique.memberCount) members")
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No unlinked Cloud Cliques")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
            Text("Create a Cloud Clique from iMessage first.")
                .font(.caption)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func linkClique(_ clique: CloudCliqueInfo) {
        isLinking = true
        Task {
            do {
                try await CloudCliqueService.linkAlbum(cliqueId: clique.cliqueId, albumTitle: albumTitle)
                await cloudCliquesStore.refresh()
                onLinked?()
                dismiss()
            } catch {
                print("[CliquePickerSheet] Link failed: \(error)")
                isLinking = false
            }
        }
    }

    private func unlinkClique(_ clique: CloudCliqueInfo) {
        isLinking = true
        Task {
            do {
                try await CloudCliqueService.unlinkAlbum(cliqueId: clique.cliqueId)
                await cloudCliquesStore.refresh()
                onLinked?()
                dismiss()
            } catch {
                print("[CliquePickerSheet] Unlink failed: \(error)")
                isLinking = false
            }
        }
    }
}
