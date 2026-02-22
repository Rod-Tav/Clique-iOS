//
//  CliqueListView.swift
//  CliqueMessages
//
//  List view showing user's cliques in the iMessage extension
//

import SwiftUI


struct CliqueListView: View {
    @Environment(ExtensionViewModel.self) var viewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.cliques.isEmpty {
                emptyState
            } else {
                cliqueList
            }
        }
        .background(Color.extensionBackground)
    }

    // MARK: - Subviews

    private var header: some View {
        Text("Your Cliques")
            .font(.headline)
            .foregroundStyle(Color.extensionPrimaryText)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.extensionSecondaryBackground)
    }

    private var cliqueList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.cliques) { clique in
                    CliqueRowView(clique: clique)
                        .contentShape(.rect)
                        .onTapGesture {
                            viewModel.selectClique(clique)
                        }

                    if clique.id != viewModel.cliques.last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.extensionSecondaryText.opacity(0.5))

            VStack(spacing: 4) {
                Text("No Cliques Yet")
                    .font(.headline)
                    .foregroundStyle(Color.extensionPrimaryText)

                Text("Open the Clique app to create and join cliques")
                    .font(.subheadline)
                    .foregroundStyle(Color.extensionSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Clique Row View

struct CliqueRowView: View {
    let clique: CachedClique

    var body: some View {
        HStack(spacing: 12) {
            ExtensionThumbnailView(urlString: clique.thumbUrl, type: .cliqueRow)

            VStack(alignment: .leading, spacing: 4) {
                Text(clique.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.extensionPrimaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(clique.memberCount)")
                        .font(.subheadline)
                        .foregroundStyle(Color.extensionSecondaryText)

                    Text("members")
                        .font(.subheadline)
                        .foregroundStyle(Color.extensionSecondaryText)

                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(Color.extensionSecondaryText)

                    Text("\(clique.flickCount)")
                        .font(.subheadline)
                        .foregroundStyle(Color.extensionSecondaryText)

                    Text("flicks")
                        .font(.subheadline)
                        .foregroundStyle(Color.extensionSecondaryText)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.extensionBackground)
    }
}

// MARK: - Preview

#if DEBUG
struct CliqueListView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with cliques
        CliqueListView()
            .environment(mockViewModelWithCliques())

        // Preview empty state
        CliqueListView()
            .environment(mockViewModelEmpty())
    }

    static func mockViewModelWithCliques() -> ExtensionViewModel {
        let viewModel = ExtensionViewModel()
        viewModel.cliques = [
            CachedClique(
                id: "1",
                name: "Best Friends",
                thumbUrl: "https://picsum.photos/200",
                memberCount: 5,
                flickCount: 42
            ),
            CachedClique(
                id: "2",
                name: "Family Vacation 2024",
                thumbUrl: "https://picsum.photos/201",
                memberCount: 8,
                flickCount: 127
            ),
            CachedClique(
                id: "3",
                name: "Work Team",
                thumbUrl: "https://picsum.photos/202",
                memberCount: 12,
                flickCount: 89
            )
        ]
        return viewModel
    }

    static func mockViewModelEmpty() -> ExtensionViewModel {
        let viewModel = ExtensionViewModel()
        viewModel.cliques = []
        return viewModel
    }
}
#endif
