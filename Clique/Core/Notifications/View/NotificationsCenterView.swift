//
//  NotificationsCenterView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI
import AdvancedList
import Toasts

// MARK: - Body
struct NotificationsCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
   
    @State private var viewModel: NotificationsPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @State private var showInboxSheet: Bool = false
    
    @State private var hasInboxNotification: Bool = false
    
    init(_ userStore: UserStore, _ cliqueStore: CliqueStore, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.viewModel = .init(userStore, cliqueStore, collectionStore, collectionImageStore)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TopAppBar(
                type: .medium,
                leadingIcon: {
                    BackButton(color: .theme.iconPrimary, size: 24)
                },
                header: {
                    HStack(spacing: 12) {
                        Text("Notifications")
                            .font(.title3.bold())
                            .kerning(0.072)
                            .textPrimary()
                        
//                        NotificationsPill()
                    }
                },
                trailingIcon: {
                    Spacer().frame(24)
//                    Button {
//                        showInboxSheet = true
//                    } label: {
//                        IconImage("message", color: .theme.iconPrimary, size: 24)
//                            .overlayTopRightNotification(when: hasInboxNotification)
//                    }.buttonStyle(.noHighlight)
                }
            )
            .padding(.vertical, 12)
            
            if hasInboxNotification {
                Button {
                    showInboxSheet = true
                } label: {
                    HStack(spacing: 8) {
                        IconImage("add-user", color: .theme.iconPrimary, size: 32)
                        
                        Text("Follow Requests and Clique Invites")
                            .font(.footnote)
                            .textPrimary()
                        
                        Spacer()
                        
                        IconImage("dot", color: .theme.red, size: 24)
                        
                        IconImage("chevron-right", color: .theme.iconPrimary, size: 16)
                    }
                }
                .contentShape(.rect)
                .padding(.bottom, 16)
            }
            
            AdvancedList(viewModel.items, listView: { notis in
                NotificationsList(notis)
            }, content: { noti in
                NotificationListCellView(notification: noti)
            }, listState: listState, emptyStateView: {
                EmptyStateView()
            }, errorStateView: { _ in
                ErrorStateView()
            }, loadingStateView: {
                LoadingStateView()
            })
            .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateNotis(.loadNextPage) } }) { })
            .onAppear {
                Task {
                    guard listState == .loading else { return }
                    await updateNotis(.loadFirstPage)
                }
            }
        }
        .frameTop()
        .padding(.horizontal, 16)
        .sheet(isPresented: $showInboxSheet) {
            InboxView(hasInboxNotification: $hasInboxNotification, userStore, cliqueStore)
//                .environment(inboxCoordinator)
                .bottomSheetModifiers()
        }
        .bottomTabBarPadding()
        .primaryBackground()
        .onReceive(of: .checkInboxNotifications) { _ in
            Task {
                do {
                    hasInboxNotification = try await NotificationService.getNotificationInviteStatus(.init())
                } catch {
                    hasInboxNotification = false
                }
            }
        }
        .onDisappear {
            if tabViewCoordinator.hasNotification {
                trigger(.checkNotifications)
            }
        }
    }
    
    @ViewBuilder private func NotificationsList(_ notis: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: notis)
        }
        .scrollBarIgnorePadding(16)
        .refreshable {
            guard paginationState == .idle else { return }
            
            // Clear cache for notifications before refreshing
            await CacheControl.shared.refreshNotifications()
            
            await updateNotis(.refresh)
        }
    }
    
    // TODO: sorting should probably be done on our side
//    @ViewBuilder private func NotificationsList() -> some View {
//        ScrollView {
//            ForEach(NotificationSection.allCases, id: \.self) { section in
//                if let sectionNotifications = viewModel.groupedNotifications[section] {
//                    VStack(alignment: .leading, spacing: 8) {
//                        Text(section.rawValue)
//                            .textSecondary()
//                            .font(.footnote.bold())
//                        
//                        LazyVStack(spacing: 16) {
//                            ForEach(sectionNotifications) { notification in
//                                NotificationListCellView(notification: notification)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        .scrollBarIgnorePadding(16)
//    }
}

// MARK: - Carousel
//extension NotificationsCenterView {
//    /// Top carousel of cliques
//    @ViewBuilder private func CliqueCarousel() -> some View {
//        ScrollView(.horizontal) {
//            LazyHStack(spacing: 16) {
//                ForEach(Clique.MOCK_CLIQUES) { clique in
//                    NavigationLink(value: clique) {
//                        CliquePfpAsyncView(pfp: clique.cliquePic, type: .cliquehubCarousel)
//                    }.buttonStyle(.noHighlight)
//                }
//            }
//        }
//        .fixedSize(horizontal: false, vertical: true)
//        .contentMargins(.vertical, 12)
//        .scrollIndicators(.hidden)
////        .onChange(of: inboxCoordinator.triggerRefresh) {
////            refresh
////            scroll carousel to first
////        }
//    }
//}

// MARK: - Pagination state views
extension NotificationsCenterView {
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateNotis(.refresh)
        }
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateNotis(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
