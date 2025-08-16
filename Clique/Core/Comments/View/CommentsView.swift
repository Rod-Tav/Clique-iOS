//
//  CommentsView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/15/24.
//

import SwiftUI
import AdvancedList
import Toasts

struct CommentsView: View {
    @Environment(\.presentToast) private var presentToast
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    @Environment(CommentStore.self) private var commentStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var commentsPgVM: CommentsPaginationViewModel
    @State private var viewModel: CommentsViewModel
    
    @State private var addCommentText: String = ""
    @FocusState private var addCommentIsFocused: Bool
    @State private var isCommentUploading: Bool = false
    
    @State private var scrollID: String?
    @State private var triggerScrollToTop: Bool = false
    
    @State private var showReplySheet: Bool = false
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @Binding var commentCount: Int?
    
    private var forceDarkTheme: Bool = false
    private var fromCollectionDetail: Bool = false
    
    init(collectionImage: CollectionImage, commentCount: Binding<Int?>, fromCollectionDetail: Bool, _ commentStore: CommentStore, _ userStore: UserStore) {
        commentsPgVM = .init(collectionItemId: collectionImage.id, commentStore, userStore)
        viewModel = .init(collectionItemId: collectionImage.id)
//        self.forceDarkTheme = true
        self.fromCollectionDetail = fromCollectionDetail
        self._commentCount = commentCount
    }
    
    var body: some View {
        //        ZStack {
        VStack(alignment: .leading, spacing: 0) {
            TopBar()
            
            PaginatedList()
                .padding(.horizontal, 16)
            
            AddCommentButton()
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .background(forceDarkTheme ? Color.theme.surfacesElevatedBlurDarkest : Color.theme.surfacesElevatedBlur)
                .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
                .shadow(color: .theme.strokeSecondary, radius: 5, x: 0, y: -5) // TODO: specific shadow color for add comment
        }
        .onChange(of: viewModel.replyingToComment) { oldValue, newValue in
            if !addCommentIsFocused, newValue != nil {
                addCommentIsFocused = true
            }
        }
//        .background(forceDarkTheme ? Color.theme.surfacesElevatedBlurDarkest : Color.theme.surfacesElevatedBlur)
        .padding(.bottom, addCommentIsFocused ? 0 : safeAreaInsets.bottom)
        .ignoresSafeArea(.container)
        .onAppear {
            guard tabViewCoordinator.focusCommentKeyboard else { return }
            addCommentIsFocused = true
            tabViewCoordinator.focusCommentKeyboard = false
        }
        
//        .padding(.bottom, 8) // for when keyboard shows
//        .sheet(isPresented: $showReplySheet) {
//            CommentEntryView(replyingToUser: $replyingToUser)
//                .frameTop()
//        }
    }
    
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {},
            header: {
                Text("Comments")
                    .foregroundStyle(forceDarkTheme ? .theme.shadesWhite95 : Color.theme.textPrimary)
                    .font(.callout.weight(.semibold))
            },
            trailingIcon: {}
        )
        .padding(.bottom, 16)
    }
}

// MARK: - Paginated list
extension CommentsView {
    @ViewBuilder private func PaginatedList() -> some View {
        AdvancedList(commentsPgVM.items, listView: { comments in
            CommentList(comments)
        }, content: { commentID in
            if let comment = commentStore.comments[commentID] {
                CommentCellP(comment)
            }
        }, listState: listState, emptyStateView: {
            EmptyStateView()
        }, errorStateView: { _ in
            ErrorStateView()
        }, loadingStateView: {
            LoadingStateView()
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateComments(.loadNextPage) } }) { })
        .task {
            guard listState == .loading else { return }
            await updateComments(.loadFirstPage)
        }
        .frameTop()
    }
    
    @ViewBuilder private func CommentList(_ comments: AdvancedList.Rows) -> some View {
        @Bindable var bindableVM = viewModel
        
        ScrollView {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .frame(1)
                    .id("TOP")
                
                LazyVStack(spacing: 16, content: comments)
                    .padding(.top, -1)
                
                Spacer()
                    .frame(height: 16)
            }
        }
        .scrollTo(id: $scrollID)
        .scrollBarIgnorePadding(16)
        .isInteracting($bindableVM.isScrolling)
        .onChange(of: triggerScrollToTop) {
            isScrollAtBottom = false
            scrollID = "TOP"
        }
    }
    
    @ViewBuilder private func CommentCellP(_ comment: Comment) -> some View {
        CommentCell(commentId: comment.id, forceDarkTheme: forceDarkTheme, fromCollectionDetail: fromCollectionDetail, commentCount: $commentCount, commentStore)
            .environment(commentsPgVM)
            .environment(viewModel)
    }
}

// MARK: - Add a comment
extension CommentsView {
    @ViewBuilder private func AddCommentButton() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let replyingToComment = viewModel.replyingToComment {
                HStack(spacing: 4) {
                    UserPfpAsyncView(pfp: replyingToComment.author.profilePic, size: 24, quality: .low)
                    
                    SmallCTA(
                        type: .secondary, 
                        text: "Replying to \(replyingToComment.author.fullname)",
                        textColor: forceDarkTheme ? .theme.shadesWhite95 : .theme.textPrimary,
                        buttonColor: forceDarkTheme ? .theme.shadesWhite15 : .theme.surfacesElevatedPrimary
                    )
                    
                    IconImage("x-icon", color: .theme.iconSecondary, size: 12)
                        .padding(5)
                        .background {
                            Circle()
                                .fill(Color.theme.surfacesElevatedPrimary)
                        }
                        .contentShape(.circle)
                        .onHighPriorityTap {
                            viewModel.replyingToComment = nil
                        }
                }
            }
            
            HStack(spacing: 8) {
                if isCommentUploading {
                    CliqueProgressView(size: 16)
                } else {
                    IconImage("comment-filled", color: forceDarkTheme ? .theme.shadesWhite95 : .theme.iconSecondary, size: 16)
                }
                
                TextField(
                    "",
                    text: $addCommentText,
                    prompt: Text("Add a comment...").foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite95 : Color.theme.textTertiary),
                    axis: .vertical
                )
                .foregroundStyle(forceDarkTheme ? Color.theme.shadesWhite95 : Color.theme.textPrimary)
                .focused($addCommentIsFocused)
                .font(.callout)
                .submitLabel(.done)
                .onEnter($of: $addCommentText) {
                    submitComment()
                }
                .limitTextField(to: 200, text: $addCommentText)
                    
            }
            .maxWidth(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(forceDarkTheme ? Color.theme.shadesWhite15 : Color.theme.buttonTertiary)
            .clipShape(.capsule)
            
            if addCommentIsFocused {
                HStack(spacing: 0) {
                    Text("\(addCommentText.count) / 200")
                        .foregroundStyle(forceDarkTheme ? .theme.shadesWhite95 : Color.theme.textPrimary)
                        .font(.callout.weight(.semibold))
                    
                    Spacer()
                    
                    TextButton("Done") {
                        submitComment()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: Upload Comment
    private func submitComment() {
        guard !addCommentText.isEmpty else {
            addCommentIsFocused = false
            viewModel.replyingToComment = nil
            return
        }
        
        Task {
            do {
                isCommentUploading = true
                
                let newComment = try await viewModel.createComment(text: addCommentText, parentId: viewModel.replyingToComment?.id)
                
                commentStore.updateComment(newComment)
                if commentCount != nil {
                    self.commentCount! += 1
                }
                
                isCommentUploading = false
                
                if let replyingToComment = viewModel.replyingToComment { // reply
                    commentStore.comments[replyingToComment.id]?.numReplies += 1
//                    commentsPgVM.items[commentsPgVM.items.firstIndex(of: replyingToComment)!].numReplies += 1
                    viewModel.replyComment = ReplyComment(comment: newComment, parentId: replyingToComment.id)
                } else { // normal comment
                    triggerScrollToTop.toggle()
                    commentStore.updateComment(newComment)
                    commentsPgVM.items.insert(newComment.id, at: 0)
                }
                
                addCommentText = ""
                addCommentIsFocused = false
                viewModel.replyingToComment = nil
            } catch {
                isCommentUploading = false
                viewModel.replyingToComment = nil
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
}

// MARK: Pagination state views
extension CommentsView {
    @ViewBuilder private func EmptyStateView() -> some View {
        VStack(spacing: 8) {
            IconImage("2-user", color: forceDarkTheme ? .theme.shadesWhite95 :.theme.iconPrimary, size: 32)
            
            Text("No one’s commented yet. Start the conversation!")
                .foregroundStyle(forceDarkTheme ? .theme.shadesWhite95 : Color.theme.textPrimary)
                .font(.footnote)
        }
        .infiniteFrame()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    listState = .loading
                    await updateComments(.refresh)
                }
            } label: {
                IconImage("refresh", color: forceDarkTheme ? .theme.shadesWhite95 :.theme.iconPrimary, size: 32)
            }
            
            Text("Something went wrong. Tap to refresh.")
                .foregroundStyle(forceDarkTheme ? .theme.shadesWhite95 : Color.theme.textPrimary)
                .multilineTextAlignment(.center)
                .font(.footnote)
        }
        .infiniteFrame()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView(forceLight: forceDarkTheme)
            .infiniteFrame()
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

#Preview {
    CommentsView(collectionImage: ClCollection.MOCK_COLLECTIONS[0].images[0], commentCount: .constant(0) ,fromCollectionDetail: true, CommentStore(), UserStore())
        .environment(TabViewCoordinator())
}



// this is the "workaround" if we want a comments entry sheet that doesn't mess up this sheet

//            if entrySheetPresented {
//                Color.black.opacity(0.05)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        entrySheetPresented = false
//                    }
//
//                VStack {
//                    Spacer()
//
//                    CommentEntryView(isPresented: $entrySheetPresented, viewModel: $viewModel)
////                        .frame(height: UIScreen.main.bounds.height * 0.15)
//                        .background(Color(uiColor: .systemBackground))
//                        .cornerRadius(10)
//
//                }.transition(.move(edge: .bottom))
//            }
//        }.animation(.interactiveSpring, value: entrySheetPresented)
