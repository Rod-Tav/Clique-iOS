//
//  UploadProgressView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/11/25.
//

import SwiftUI

struct UploadProgressView: View {
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore

    @Environment(TabViewCoordinator.self) private var tabViewCoordinator

    let collectionId: String
    var totalFlicks: Int
    var successfulFlicks: Double
    var failedFlicks: Int

    @Binding var showUploading: Bool

    var showNav: Bool = false

    var showRetry: Bool = false
    var retryAction: () -> Void

    @State private var tapped: Bool = false
    @State private var isSwiping: Bool = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Button {
                guard showNav else { return }
                print("✅ Button tapped, showNav: \(showNav)")
                navAction()
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(showNav ? Color.theme.buttonCTA : Color.theme.surfacesBackgroundPrimary.opacity(0.9))
                    .contentShape(.rect)
            }
            .disabled(!showNav || isSwiping)

            VStack(alignment: .leading) {
                if showNav {
                    Spacer()
                }

                HStack {
                    if showNav {
                        HStack(spacing: 4) {
                            if !showRetry {
                                Spacer()
                            }

                            Text("Tap to go to collection")
                                .foregroundStyle(Color.theme.buttonContent)
                                .multilineTextAlignment(.leading)
                                .font(.callout)

                            if !showRetry {
                                Spacer()
                            }

                            IconImage("chevron-right", color: .theme.buttonContent, size: 16)
                        }
                        .allowsHitTesting(false)
                    } else if totalFlicks == 0 {
                        HStack(spacing: 8) {
                            CliqueProgressView(size: 20)

                            Text("Processing images for upload...")
                                .textPrimary()
                                .font(.callout)
                        }
                    } else {
                        // Display integer count for text, but use fractional progress for bar
                        let displayCount = Int(successfulFlicks.rounded(.down))
                        Text("Uploading \(displayCount) / \(totalFlicks)...")
                            .textPrimary()
                            .font(.callout.bold())
                    }

                    if showRetry {
                        Spacer()

                        Button {
                            print("retry tapped")
                            retryAction()
                        } label: {
                            VStack(alignment: .trailing) {
                                IconImage("refresh", color: .buttonContent, size: 20)

                                Text("Tap to retry \(failedFlicks) failed flicks")
                                    .foregroundStyle(.buttonContent)
                                    .font(.callout)
                            }
                            .contentShape(.rect)
                        }
                    }
                }
                .padding(8)

                if showNav {
                    Spacer()
                } else {
                    Spacer()

                    Capsule()
                        .fill(Color.theme.cliquePink)
                        .frame(width: max(0, CGFloat(Double(successfulFlicks) / Double(totalFlicks) * (UIScreen.width - 16))), height: 3)
                        .fixedSize(horizontal: true, vertical: true)
                }
            }
        }
        .frame(height: 48)
        .swipeDownToDismiss(isPresented: $showUploading, isSwiping: $isSwiping)
    }
    
    private func navAction() {
        guard !tapped else {
            print("⚠️ navAction blocked: already tapped")
            return
        }

        tapped = true
        print("📍 navAction called, fetching collection: \(collectionId)")

        Task {
            do {
                let collectionToNav = try await CollectionService.getCollectionById(.init(
                    path: .init(collectionDataId: collectionId),
                    query: .init(page: 0, size: 1)
                ))

                print("✅ Got collection: \(collectionToNav.name)")

                collectionStore.updateCollection(collectionToNav, collectionImageStore)
                tabViewCoordinator.navigate(to: collectionToNav)
                showUploading = false

                print("✅ Navigation completed")
            } catch {
                print("❌ Navigation failed: \(error)")
                tapped = false // Reset on error to allow retry
            }
        }
    }
}

#Preview {
    UploadProgressView(collectionId: "", totalFlicks: 100, successfulFlicks: 100, failedFlicks: 2, showUploading: .constant(false), showNav: true, showRetry: true, retryAction: { })
        .padding(.horizontal, 16)
        .environment(CollectionStore())
        .environment(CollectionImageStore())
        .environment(TabViewCoordinator())
}
