//
//  ProfileCollectionsCell.swift
//  Clique
//
//  Created by Rod Tavangar on 7/21/24.
//

import SwiftUI
import Toasts

struct CollectionGridCell: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @State private var viewModel = CollectionViewModel()
    @State private var cliqueMembersVM: CliqueProfileViewModel
    
    let collectionId: String
    let showClique: Bool
    
    init(collectionId: String, cliqueId: String) {
        self.collectionId = collectionId
        self.cliqueMembersVM = .init(cid: cliqueId)
        self.showClique = true
    }
    
    init(collectionId: String) {
        self.collectionId = collectionId
        self.cliqueMembersVM = .init(cid: "")
        self.showClique = false
    }
    
    private var collection: ClCollection? {
        collectionStore.collections[collectionId]
    }
    
    private var clique: Clique? {
        if let collection {
            return cliqueStore.cliques[collection.cliqueId]
        } else {
            return nil
        }
    }
    
    var body: some View {
        let side = UIScreen.width * ScaleFactors.userProfileCollectionCoverPhoto
        
        if let collection {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                            .frame(side)
                            .scaleEffect(0.77, anchor: .top)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.theme.surfacesBackgroundPrimary)
                            .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                            .frame(side)
                            .scaleEffect(0.90, anchor: .top)
                            .offset(y: 3.38 / 2)
                        
                        Group {
                            if let coverPhoto = collection.coverPhoto {
                                ProfileCollectionCoverPhotoAsyncImage(urls: coverPhoto, side: side, quality: .low)
                            } else if let mostLikedImage = collection.mostLikedImage,
                                      let image = collectionImageStore.images[mostLikedImage],
                                      image.uploadStatus != .PENDING,
                                      let urls = image.imageUrl {
                                ProfileCollectionCoverPhotoAsyncImage(urls: urls, side: side, quality: .low, uploadStatus: image.uploadStatus)
                            } else {
                                ProfileCollectionPlaceholder(side: side)
                            }
                        }
                        .offset(y: 3.38)
                    }
                    .overlay(alignment: .topLeading) {
                        if showClique, let clique {
                            CliquePfpAsyncView(pfp: clique.cliquePic, type: .collectionPreview, hasBorder: false, quality: .low)
                                .overlay( // TODO: lazy
                                    RoundedRectangle(cornerRadius: 4)
                                        .inset(by: -0.25)
                                        .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                                )
                                .offset(y: -3.38)
                                .padding(.leading, 6)
                                .padding(.top, 12)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if collection.visibility == .priv {
                            IconImage("lock", color: .theme.white, size: 16)
                                .padding([.trailing, .top], 5.7)
                                .offset(y: 3.38)
                            //                                .alignmentGuide(.bottom) {$0[VerticalAlignment.center]}
                            //                                .offset(x: -5.38, y: 2)
                        }
                    }
                }
                
                VStack(spacing: 0) {
                    if showClique, !cliqueMembersVM.firstXMembers.isEmpty {
                        CliqueCircularMembersView(members: cliqueMembersVM.firstXMembers, memberLimit: 6, type: .cliqueListCell)
                            .padding(.bottom, 4)
                        //                                .offset(y: 3.38)
                    }
                    
                    Text(collection.name)
                        .font(.footnote.weight(.semibold))
                        .textPrimary()
                        .lineLimit(1)
                        .padding(.bottom, 2)
                    
                    if showClique {
                        HStack(spacing: 2) {
                            IconImage("3-user", color: .theme.iconSecondary, size: 12)
                            
                            Group {
                                if let clique {
                                    Text(clique.name)
                                        .lineLimit(1)
                                }

                                Text("•")

                                Text("\(collection.displayFlickCount(currentUserId: userStore.currentUserId))")
                            }
                            .font(.caption2)
                            .textSecondary()
                        }
                    } else {
                        Text("\(collection.displayFlickCount(currentUserId: userStore.currentUserId))") // TODO: DRY
                            .font(.caption2)
                            .textSecondary()
                    }
                }
                // TODO: figure out
                .padding(.top, showClique && !cliqueMembersVM.firstXMembers.isEmpty ? -5.5 : 12)
            }
            .fetchMostLikedImage(collectionId: collectionId)
            .onAppear { // TODO: DRY
                guard showClique else { return }
                
                Task {
                    guard let clique, cliqueMembersVM.firstXMembers.count < min(clique.numMembers, 6) else { return }
                    
                    do {
                        try await cliqueMembersVM.fetchCliqueFirstXMembers(count: 6, total: clique.numMembers, userStore, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
            .frame(maxWidth: side)
            .onAppear {
                Task {
                    do {
                        try await viewModel.fetchClique(cid: collection.cliqueId, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
        }
    }
}
