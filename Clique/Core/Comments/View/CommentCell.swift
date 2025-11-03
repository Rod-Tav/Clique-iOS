//
//  CommentCell.swift
//  Clique
//
//  Created by Rod Tavangar on 7/15/24.
//

import SwiftUI
import Toasts
import AdvancedList

struct CommentCell: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CommentStore.self) private var commentStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(CommentsPaginationViewModel.self) private var commentsPgVM
    @Environment(CommentsViewModel.self) private var commentsCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var viewModel = CommentViewModel()
    @State private var repliesPgVM: CommentRepliesPaginationViewModel
    
    @State private var likedReplies = Set<String>() // comment ids
    @State private var showReplies: Bool = false
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @Binding var commentCount: Int?
    
    private var forceDarkTheme: Bool
    private var fromCollectionDetail: Bool
    
    let commentId: String
    
    init(commentId: String, forceDarkTheme: Bool = false, fromCollectionDetail: Bool = false, commentCount: Binding<Int?>, _ commentStore: CommentStore) {
        self.commentId = commentId
        self.repliesPgVM = .init(parentId: commentId, commentStore)
        self.forceDarkTheme = forceDarkTheme
        self.fromCollectionDetail = fromCollectionDetail
        self._commentCount = commentCount
    }
    
    private var comment: Comment? {
        commentStore.comments[commentId]
    }
    
    
    // MARK: - Body
    var body: some View {
        Button {
            if let comment {
                navigate(to: comment.author)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    UserPfpAsyncView(pfp: comment?.author.profilePic, size: 32, quality: .low)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let comment {
                                    HStack(spacing: 4) {
                                        Text(comment.author.username)
                                            .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite95 : Color.theme.textPrimary)
                                            .font(.footnote.weight(.semibold))
                                        
                                        Text(formatRelativeDate(comment.dateCreated))
                                            .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite50 : Color.theme.textTertiary)
                                            .font(.caption)
                                    }
                                    
                                    Text(comment.text)
                                        .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite95 : Color.theme.textPrimary)
                                        .font(.footnote)
                                }
                            }
                            
                            Spacer()
                            
                            LikeButton()
                        }

                        ReplyButton()
                    }
                }
                .background {
                    // TODO: if first comment in list, doesn't cover top padding
                    if comment?.id == commentsCoordinator.replyingToComment?.id {
                        Group {
                            if forceDarkTheme {
                                Color.theme.shadesWhite15
                            } else {
                                Color.theme.strokeTertiary
                                
                            }
                        }
                        .padding(.horizontal, -16)
                        .padding(.vertical, -8)
                    } else {
                        Color.clear
                    }
                }

                
                if let comment, comment.numReplies > 0 {
                    Group {
                        ViewReplies()
                        
                        if showReplies {
                            AdvancedList(repliesPgVM.items, listView: { replies in
                                RepliesList(replies)
                            }, content: { replyID in
                                if let reply = commentStore.comments[replyID.id] {
                                    ReplyCell(reply)
                                }
                            }, listState: listState, emptyStateView: {
                                EmptyStateView()
                            }, errorStateView: { _ in
                                ErrorStateView()
                            }, loadingStateView: {
                                LoadingStateView()
                            })
                            .frameTop()
                        }
                    }
                    .padding(.leading, 40)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.noHighlight)
        .disabled(commentsCoordinator.isScrolling)
        .onChange(of: commentsCoordinator.replyComment) { _, newValue in
            guard let newReply = newValue, newReply.parentId == comment?.id else { return }
            
            print("Adding reply")
            if !showReplies {
                if repliesPgVM.items.isEmpty {
                    Task { await updateReplies(.loadFirstPage) }
                } else {
//                    if !repliesPgVM.items.contains(where: { $0.id == newReply.comment.id }) {
                    repliesPgVM.items.insert(.init(newReply.comment.id), at: 0)
//                    }
                }
                showReplies = true
            } else {
//                if !repliesPgVM.items.contains(where: { $0.id == newReply.comment.id }) {
                repliesPgVM.items.insert(.init(newReply.comment.id), at: 0)
//                }
            }
            
            commentsCoordinator.replyComment = nil
        }
    }
}
    
// MARK: - Likes
extension CommentCell {
    /// Like button
    @ViewBuilder private func LikeButton() -> some View {
        if let comment {
            Button {
                handleLikeTapped()
            } label: {
                VStack(alignment: .center, spacing: 4) {
                    IconImage(
                        name: comment.hasLiked ? "heart-filled" : "heart-stroke",
                        color: comment.hasLiked ? .theme.red : forceDarkTheme ? .theme.shadesWhite65 : .theme.iconSecondary,
                        size: 16
                    )
                    
                    Text("\(comment.numLikes)")
                        .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite95 : Color.theme.textSecondary)
                        .font(.caption2)
                }
                .contentShape(.rect)
            }
        }
    }
    
    private func handleLikeTapped() {
        if let comment {
            haptics(.light)
            
            commentStore.comments[commentId]?.hasLiked.toggle()
            let oldNumLikes = comment.numLikes
            
            Task {
                do {
                    if comment.hasLiked {
                        commentStore.comments[commentId]?.numLikes -= 1
                        try await viewModel.unlikeComment(id: comment.id)
                    } else {
                        commentStore.comments[commentId]?.numLikes += 1
                        try await viewModel.likeComment(id: comment.id)
                    }
                } catch {
                    commentStore.comments[commentId]?.hasLiked.toggle()
                    commentStore.comments[commentId]?.numLikes = oldNumLikes
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
    }
}
    
// MARK: - Replies
extension CommentCell {
    /// Reply to comment button
    @ViewBuilder private func ReplyButton() -> some View {
        if let comment {
            HStack(spacing: 4) {
                Button {
                    commentsCoordinator.replyingToComment = comment
                } label: {
                    Text("Reply")
                        .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.textSecondary)
                        .font(.footnote)
                }
                
                Menu {
                    if comment.author.id == userStore.currentUserId {
                        DeleteButton { // TODO: DRY
                            Task {
                                do {
                                    // order here matters
                                    // could store id but then catch becomes a bit strange (adding back) so this is fine
                                    try await viewModel.deleteComment(id: comment.id)
                                    commentsPgVM.removeComment(id: comment.id)
                                    if commentCount != nil {
                                        self.commentCount! -= 1
                                    }
                                    commentStore.comments.removeValue(forKey: comment.id)
                                    if commentsCoordinator.replyingToComment?.id == comment.id {
                                        commentsCoordinator.replyingToComment = nil
                                    }
                                } catch {
                                    presentToast(Toasts.somethingWentWrong)
                                }
                            }
                        }
                    }
                    
                    ReportButton {
                        // report
                    }
                } label: {
                    IconImage(name: "ellipsis", color: forceDarkTheme ? .theme.shadesWhite65 : .theme.iconSecondary, size: 16)
                }
            }
        }
    }
    
    /// View replies dropdown
    @ViewBuilder private func ViewReplies() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                showReplies.toggle()
                Task {
                    await updateReplies(.loadFirstPage)
                }
            } label: {
                HStack(spacing: 8) {
                    Divider()
                        .frame(width: 32, height: 1.5)
                        .background(forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.iconSecondary)
                    
                    HStack(spacing: 2) {
                        if let comment {
                            Text(showReplies ? "Hide replies" : "View \(pluralizeWithCount(count: comment.numReplies, singular: "Reply", plural: "Replies"))")
                                .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.textSecondary)
                                .font(.caption.weight(.semibold))
                        }
                        
                        IconImage(name: "chevron-right", color: forceDarkTheme ? .theme.shadesWhite65 : .theme.iconSecondary, size: 12)
                            .rotationEffect(.degrees(showReplies ? 90 : 0))
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func RepliesList(_ replies: AdvancedList.Rows) -> some View {
        if let comment {
            VStack(alignment: .leading, spacing: 16) {
                LazyVStack(spacing: 16, content: replies)
                
                if repliesPgVM.items.count < comment.numReplies, !repliesPgVM.done {
                    Button {
                        Task {
                            await updateReplies(.loadNextPage)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Divider()
                                .frame(width: 32, height: 1.5)
                                .background(Color.theme.iconSecondary)
                            
                            HStack(spacing: 2) {
                                Text("View more replies")
                                    .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.textSecondary)
                                    .font(.caption.weight(.semibold))
                                
                                IconImage(name: "chevron-right", color: forceDarkTheme ? .theme.shadesWhite65 : .theme.iconSecondary, size: 12)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func navigate(to user: User) {
        dismiss()
        if fromCollectionDetail {
            tabViewCoordinator.pan = .disabled // TODO: weird ass behavior
            appCoordinator.lookingAtUserProfileFromCollectionDetail = true
            tabViewCoordinator.showTabBar = true
        }
        
        tabViewCoordinator.navigate(to: user)
    }
    
    @ViewBuilder private func ReplyCell(_ reply: Comment) -> some View {
        Button {
            navigate(to: reply.author)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                UserPfpAsyncView(pfp: reply.author.profilePic, size: 32, quality: .low)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(reply.author.username)
                                    .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.textSecondary)
                                    .font(.footnote.weight(.semibold))
                                
                                Text(formatRelativeDate(reply.dateCreated))
                                    .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite50 : Color.theme.textTertiary)
                                    .font(.caption)
                                
                                Menu {
                                    if reply.author.id == userStore.currentUserId {
                                        DeleteButton {
                                            Task {
                                                do {
                                                    try await viewModel.deleteComment(id: reply.id)
                                                    repliesPgVM.items.removeAll(where: { $0.id == reply.id })
                                                    commentStore.comments[commentId]?.numReplies -= 1
                                                    if commentCount != nil {
                                                        self.commentCount! -= 1
                                                    }
                                                    commentStore.comments.removeValue(forKey: reply.id)
                                                } catch {
                                                    presentToast(Toasts.somethingWentWrong)
                                                }
                                            }
                                        }
                                    }
                                    
                                    ReportButton {
                                        // report
                                    }
                                } label: {
                                    EllipsisImage(color: forceDarkTheme ? .theme.shadesWhite65 : .theme.iconSecondary, size: 16)
                                }
                            }
                            
                            Text(reply.text)
                                .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite95 : Color.theme.textPrimary)
                                .font(.footnote)
                        }
                        
                        Spacer()
                        
                        Button {
                            let oldLikedReplies = likedReplies
                            haptics(.light)
                            
                            Task {
                                do {
                                    if likedReplies.contains(reply.id) {
                                        likedReplies.remove(reply.id)
                                        try await viewModel.unlikeComment(id: reply.id)
                                    } else {
                                        likedReplies.insert(reply.id)
                                        try await viewModel.likeComment(id: reply.id)
                                    }
                                } catch {
                                    likedReplies = oldLikedReplies
                                    presentToast(Toasts.somethingWentWrong)
                                }
                            }
                        } label: {
                            let hasLiked = likedReplies.contains(reply.id)
                            
                            VStack(alignment: .center, spacing: 4) {
                                Image(hasLiked ? "heart-filled" : "heart-stroke")
                                    .icon(color: hasLiked ? .theme.red : forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.iconSecondary, size: 16)
                                
                                Text("\(reply.numLikes + ((hasLiked && !reply.hasLiked) ? 1 : (!hasLiked && reply.hasLiked) ? -1 : 0))")
                                    .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite65 : Color.theme.textSecondary)
                                    .font(.caption2)
                            }
                            .contentShape(.rect)
                        }
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.noHighlight)
        .onAppear {
            if reply.hasLiked {
                likedReplies.insert(reply.id)
            }
        }
    }
    
    // MARK: Pagination state views for replies (?)
    // need to abstract with the ones in CommentsView with force dark logic too
    @ViewBuilder private func EmptyStateView() -> some View {
        // this shouldn't happen
        VStack(spacing: 8) {
            EmptyView()
        }
        .infiniteFrame()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    listState = .loading
                    await updateReplies(.refresh)
                }
            } label: {
                IconImage(name: "refresh", color: forceDarkTheme ? .theme.shadesWhite95 :.theme.iconPrimary, size: 32)
            }
            
            Text("Something went wrong. Tap to refresh.")
                .foregroundStyle(forceDarkTheme ? .theme.shadesWhite95 : Color.theme.textPrimary)
                .multilineTextAlignment(.center)
                .font(.footnote)
        }
        .infiniteFrame()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateReplies(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: repliesPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}

#Preview {
    CommentCell(commentId: Comment.MOCK_COMMENTS[0].id, commentCount: .constant(0), CommentStore())
        .environment(CommentsPaginationViewModel(collectionItemId: ClCollection.MOCK_COLLECTIONS[0].id, CommentStore(), UserStore()))
        .environment(CommentsViewModel(collectionItemId: ClCollection.MOCK_COLLECTIONS[0].id))
        .environment(TabViewCoordinator())
}
