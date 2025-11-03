//
//  FeedCellCommentsOverlay.swift
//  Clique
//
//  Created by Rod Tavangar on 3/1/25.
//

import SwiftUI
import AdvancedList

struct FeedCellBottomOverlay: View {
    @Environment(CommentStore.self) private var commentStore
    
    @Environment(CommentsPaginationViewModel.self) private var commentsPgVM
    
    @Binding var listState: ListState
    @Binding var paginationState: AdvancedListPaginationState
    @Binding var isScrollAtBottom: Bool
    
    @State private var commentScrollID: String?
    @State private var isScrollingComments: Bool = false
    @Binding var showSheet: Bool
    
    let hasLiked: Bool
    let numLikes: Int
    let handleLikeTapped: () -> Void
    let handleLikeCountTapped: () -> Void
    let numComments: Int
    let showCommentsPaging: Bool

    var body: some View {
        HStack(spacing: 16) {
            if showCommentsPaging {
                Comments()
                    .frame(height: 16)
                    .onTapGesture {
                        showSheet = true
                    }
            }

//            IconAndNumber(
//                iconName: "heart-filled",
//                iconColor: hasLiked ? Color.theme.red : Color.theme.white,
//                iconSize: 20,
//                count: numLikes,
//                onTap: {
//                    haptics(.medium)
//                    handleLikeTapped()
//                }
//            )

            HStack(spacing: 4) {
                Button {
                    haptics(.medium)
                    handleLikeTapped()
                } label: {
                    IconImage(name: "heart-filled", color: hasLiked ? Color.theme.red : Color.theme.white, size: 20)
                }.buttonStyle(.noHighlight)

                Button {
                    handleLikeCountTapped()
                } label: {
                    Text(formatNumber(numLikes))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.theme.white)
                }
            }

            IconAndNumber(
                iconName: "comment-filled",
                iconColor: Color.theme.white,
                iconSize: 20,
                count: numComments,
                onTap: {
                    haptics(.medium)
                    showSheet = true
                }
            )
        }
        .maxWidth(.trailing)
    }
    
    @ViewBuilder private func Comments() -> some View {
        AdvancedList(commentsPgVM.items, listView: { comments in
            CommentsList(comments)
        }, content: { commentID in
            if let comment = commentStore.comments[commentID] {
                CommentPreviewCell(comment)
            }
        }, listState: listState, emptyStateView: {
            EmptyStateView()
        }, errorStateView: { _ in
            ErrorStateView()
        }, loadingStateView: {
            LoadingStateView()
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateComments(.loadNextPage) } }) { })
        .onAppear {
            Task {
                guard listState == .loading else { return }
                await updateComments(.loadFirstPage)
            }
        }
    }
    
    @ViewBuilder private func CommentsList(_ comments: AdvancedList.Rows) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(content: comments)
                .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $commentScrollID)
        .isInteracting($isScrollingComments)
        .onAppear {
            startAutoScroll()
        }
    }
    
    @ViewBuilder private func CommentPreviewCell(_ comment: Comment) -> some View {
        HStack(spacing: 8) {
            UserPfpAsyncView(pfp: comment.author.profilePic, size: 16, quality: .low, context: .list)
            
            Text(comment.text)
                .font(.caption)
                .foregroundStyle(Color.theme.white)
        }
        .containerRelativeFrame(.horizontal, alignment: .leading)
        .id(comment.id)
    }
    
    private func startAutoScroll() {
        Task {
            guard !commentsPgVM.items.isEmpty else { return }
            
            // If commentScrollID is nil, set it to the first item but don't scroll yet.
            if commentScrollID == nil {
                commentScrollID = commentsPgVM.items.first?.id
            }
            
            // Wait one loop before starting
            try? await Task.sleep(for: .milliseconds(Constants.commentAutoScrollInterval))
            
            while true {
                guard !isScrollingComments, !commentsPgVM.items.isEmpty, !showSheet else {
                    try? await Task.sleep(for: .milliseconds(Constants.commentAutoScrollInterval)) // Ensure loop doesn't spin too fast
                    continue
                }
                
                moveToNextComment()
                
                try? await Task.sleep(for: .milliseconds(Constants.commentAutoScrollInterval)) // Regular interval
            }
        }
    }
    
    /// Moves to the next comment in the list, looping if at the end.
    private func moveToNextComment() {
        // Find the current index based on commentScrollID
        if let currentID = commentScrollID,
           let currentIndex = commentsPgVM.items.firstIndex(where: { $0.id == currentID }) {
            
            let nextIndex = (currentIndex + 1) % commentsPgVM.items.count // Loop back when reaching the end
            
            withAnimation(.easeInOut(duration: 0.5)) {
                commentScrollID = commentsPgVM.items[nextIndex].id // Move to the next comment ID
            }
        } else {
            // Default to first comment if no valid current ID
            commentScrollID = commentsPgVM.items.first?.id
        }
    }
    
    @ViewBuilder private func IconAndNumber( iconName: String, iconColor: Color, iconSize: CGFloat, count: Int, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Button {
                onTap()
            } label: {
                IconImage(iconName, color: iconColor, size: iconSize)
            }.buttonStyle(.noHighlight)
            
            Text(formatNumber(count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.theme.white)
        }
    }
}

// MARK: - Pagination states
extension FeedCellBottomOverlay {
    @ViewBuilder private func EmptyStateView() -> some View {
        Color.clear
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateComments(.refresh)
        }
        .scaleEffect(0.5)
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        Color.clear
    }
    
    private func updateComments(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: commentsPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
