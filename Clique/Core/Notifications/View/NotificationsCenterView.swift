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
                inboxButton
            }
            
            AdvancedList(viewModel.items, listView: { notis in
                NotificationsList(notis)
            }, content: { noti in
                NotificationListCellView(notification: noti)
            }, listState: listState, emptyStateView: {
                emptyStateView
            }, errorStateView: { _ in
                errorStateView
            }, loadingStateView: {
                loadingStateView
            })
            .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateNotis(.loadNextPage) } }) { })
            .onAppear {
                Task {
                    guard listState == .loading else { return }
                    await updateNotis(.loadFirstPage)
                }
                
                // Check for inbox notifications (clique invites and follow requests)
                Task {
                    do {
                        hasInboxNotification = try await NotificationService.getNotificationInviteStatus(.init())
                    } catch {
                        hasInboxNotification = false
                    }
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
    
    // MARK: - Notifications List
    private func NotificationsList(_ notis: AdvancedList.Rows) -> some View {
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
    
    // MARK: Inbox Button
    private var inboxButton: some View {
        Button {
            showInboxSheet = true
        } label: {
            HStack(spacing: 12) {
                // Icon with background circle
                ZStack {
                    Circle()
                        .fill(Color.theme.cliquePink.opacity(0.3))
                        .frame(44)
                    
                    IconImage("add-user", color: .theme.cliquePink, size: 24)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Requests")
                        .font(.subheadline.weight(.semibold))
                        .textPrimary()
                    
                    Text("Follow Requests and Clique Invites")
                        .font(.caption)
                        .textSecondary()
                }
                
                Spacer()
                
                // Red notification dot
                Circle()
                    .fill(Color.theme.red)
                    .frame(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.theme.cliquePink.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.theme.cliquePink, lineWidth: 0.5)
                    )
            )
        }
//        .padding(.horizontal, 16)
        .padding(.bottom, 16)
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
private extension NotificationsCenterView {
    var emptyStateView: some View {
        NothingHereYetView()
    }
    
    var errorStateView: some View {
        SomethingWentWrong {
            listState = .loading
            await updateNotis(.refresh)
        }
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    var loadingStateView: some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    func updateNotis(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
