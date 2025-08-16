//
//  SingleFlickView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/2/25.
//

import SwiftUI
import Toasts

struct SingleFlickView: View {
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUpToOpenComments: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var dismissing: Bool = false
    @State private var dismissOffset: CGSize = .zero
    
    @State private var likeAnimation: Bool = false
    
    @State private var showCommentSheet: Bool = false
    @State private var showLikedMembers: Bool = false
    
    let flick: CollectionImage
    let collection: ClCollection
    
    private var currentImage: CollectionImage? {
        collectionImageStore.images[flick.id]
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            
            Spacer()
            
            Flick()
            
            Spacer()
            
            BelowFlick()
        }
        // TODO: fromCollectionDetail is true because navigating to user profile is weird
        .commentSheet(imageId: flick.id, fromCollectionDetail: true, showCommentSheet: $showCommentSheet)
        .background {
            if let currentImage {
                CollectionDetailBackgroundAsyncImage(urls: currentImage.imageUrl, quality: .low)
                    .blur(radius: 12.5, opaque: true)
                    .overlay(Color.theme.surfacesImageBgDarkOverlay)
                    .overlay(.black.opacity(0.2))
            }
        }
    }
    
    private var swipeUpToOpenComments: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !dismissing else { return }
                // Check if the swipe was mostly vertical and upwards
                if value.translation.height < -20 && abs(value.translation.width) < 20 {
                    haptics(.light)
                    showCommentSheet = true
                    hasSwipedUpToOpenComments = true
                }
            }
    }
    
    // MARK: Top Bar
    @ViewBuilder func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage("x-icon", color: .theme.white, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: HeaderContent,
            trailingIcon: {
                Spacer().frame(24)
            }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func HeaderContent() -> some View {
        Button {
            dismiss()
            tabViewCoordinator.navigate(to: collection)
        } label: {
            VStack(spacing: 2) {
                Group {
                    HStack(spacing: 4) {
                        Text(collection.name)
                            .font(.callout.bold())
                        
                        IconImage("chevron-right", color: .theme.iconPrimary, size: 16)
                    }
                    
                    Text("\(formatDateMMMMdYYYY(flick.date)) • \(formatDateHHmm(flick.date))")
                        .font(.caption)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.theme.white)
            }
            .contentShape(.rect)
        }
        .noHighlight()
    }
    
    // MARK: Flick
    @ViewBuilder private func Flick() -> some View {
        if let currentImage {
            CollectionDetailImageAsyncView(urls: flick.imageUrl, quality: .high)
                .doubleTapToLike(hasLiked: currentImage.hasLiked, likeAnimation: $likeAnimation) {
                    handleLikeTapped()
                }
                .swipeUpToOpenCommentsTutorial()
                .simultaneousGesture(swipeUpToOpenComments)
                .offset(dismissOffset)
                .simultaneousGesture(swipeDownToDismiss)
                .overlay {
                    IconImage("heart-filled", color: .theme.red, size: 70)
                        .likeAnimation($likeAnimation)
                }
        }
    }
    
    // MARK: Below Flick
    @ViewBuilder private func BelowFlick() -> some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                Button {
                    tabViewCoordinator.focusCommentKeyboard = true
                    showCommentSheet = true
                } label: {
                    ZStack(alignment: .leading) {
                        if let currentUser = userStore.currentUser {
                            UserPfpAsyncView(pfp: currentUser.profilePic, size: 32, quality: .low)
                                .zIndex(1)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Add a comment...")
                                .font(.footnote)
                                .foregroundColor(Color.theme.white)
                                .maxWidth(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .roundCorners(16)
                        .maxWidth()
                        .offset(x: 32-8)
                        .padding(.trailing, 32-8)
                    }
                    .maxWidth(.leading)
                }.buttonStyle(.noHighlight)
                
                if let currentImage {
                    HStack(spacing: 6) { // TODO: DRY
                        Button {
                            haptics(.medium)
                            handleLikeTapped()
                        } label: {
                            IconImage("heart-filled", color: currentImage.hasLiked ? .theme.red : .theme.white, size: 28)
                        }
                        
                        Button {
                            showLikedMembers = true
                        } label: {
                            Text(formatNumber(currentImage.numLikes))
                                .font(.footnote.bold())
                                .foregroundStyle(Color.theme.white)
                        }
                    }
                    .sheet(isPresented: $showLikedMembers) {
                        LikedUsersListView(imageId: currentImage.id, fromCollectionDetail: true, userStore)
                            .presentationDetents([.fraction(0.35), .fraction(0.999)])
                            .bottomSheetModifiers()
                    }
                    
                    Button {
                        showCommentSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            IconImage("comment-filled", color: .theme.white, size: 28)
                            
                            Text(formatNumber(currentImage.numComments))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.theme.white)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helpers
    private func handleLikeTapped() {
        do {
            try handleCollectionImageLikeTapped(image: flick, collectionImageStore)
        } catch {
            presentToast(Toasts.somethingWentWrong)
        }
    }
    
    // TODO: DRY
    private var swipeDownToDismiss: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard (value.translation.height > 10 && abs(value.translation.width) < 20) || dismissing else { return }
                
                dismissing = true
                dismissOffset = CGSize(width: 0, height: value.translation.height)
            }
            .onEnded { value in
                guard dismissing else { return }
                let height = value.translation.height + (value.velocity.height / 5)
                
                if height > 10 {
                    dismiss()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismissOffset = .zero
                    } completion: {
                        dismissing = false
                    }
                }
            }
    }
}
