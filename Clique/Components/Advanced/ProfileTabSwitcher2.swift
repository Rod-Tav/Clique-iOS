//
//  ProfileTabSwitcher2.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

struct ProfileTabSwitcher2<SmallHeader: View, LargeHeader: View, ContentView: View>: View {
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @Environment(TabViewCoordinator.self) private var tabCoordinator
    @Environment(ProfileTabSwitcherCoordinator.self) private var coordinator
    
    @State private var tabProgress: CGFloat = 0
    
    let smallHeaderView: SmallHeader
    let largeHeaderView: LargeHeader
    let content: ContentView
    let tabs: [any ProfileTab]? // optional for collection view, TODO: clean
    let ignoresSafeArea: Bool
    var panDisabled: Bool // from collection detail bs
    
    init(
        smallHeaderView: SmallHeader,
        largeHeaderView: LargeHeader,
        tabs: [any ProfileTab]? = nil,
        ignoresSafeArea: Bool? = true,
        panDisabled: Bool? = false,
        @ViewBuilder content: () -> ContentView
    ) {
        self.smallHeaderView = smallHeaderView
        self.largeHeaderView = largeHeaderView
        self.content = content()
        self.tabs = tabs
        self.ignoresSafeArea = ignoresSafeArea ?? false
        self.panDisabled = panDisabled ?? false
    }
    
    private var selectedTab: Int? {
        coordinator.selectedTab
    }
    
    // MARK: Body
    var body: some View {
        @Bindable var bindableVM = coordinator
        
//        GeometryReader { geo in
            VStack(spacing: 0) {
                if coordinator.smallHeader {
                    smallHeaderView
                        .contentShape(.rect)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    largeHeaderView
                        .contentShape(.rect)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if let tabs, !tabs.isEmpty {
                    Tabs()
                    
                    if #available(iOS 18.0, *) {
                        HorizontalScrollViewHelper()
                            .onScrollPhaseChange { oldPhase, newPhase in
                                if newPhase == .idle, oldPhase != .idle {
                                    coordinator.isScrolling = false
                                } else if oldPhase == .idle, newPhase != .idle {
                                    coordinator.isScrolling = true
                                }
                            }
                    } else {
                        HorizontalScrollViewHelper()
                    }
//                    HorizontalScrollViewHelper()
//                        .isInteracting($bindableVM.isScrolling)
                } else {
                    content
                }
            }
            .padding(.top, ignoresSafeArea ? -safeAreaInsets.top : 0) // ignoring safe area messes with the paging HStack
//        }
        .simultaneousGesture(snapDown)
        .simultaneousGesture(snapUp)
//        .onChange(of: selectedTab) { haptics(.light) }
        .primaryBackground()
//        .onAppear {
//            if panDisabled {
//                tabCoordinator.pan = .disabled
//            }
//        }
//        .onDisappear {
//            tabCoordinator.pan = .pan
//        }
    }
    
    @ViewBuilder private func HorizontalScrollViewHelper() -> some View {
        @Bindable var bindableVM = coordinator
        
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) { // this being lazy works on iOS 18 but on iOS 17 if you go to the second tab and swipe down it jumps to the third one
                content
//                    .environment(coordinator)
            }
            .scrollTargetLayout()
            .offsetX { value in
                tabProgress = -value / (UIScreen.width * CGFloat(tabs!.count))
            }
        }
        .maxHeight()
//        .simultaneousGesture(snapUp)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $bindableVM.selectedTab)
        .scrollClipDisabled()
    }
    
    @ViewBuilder private func Tabs() -> some View {
        TabsWithIndicatorBar(
            tabCount: tabs!.count,
            alignment: .top,
            barWidth: (UIScreen.width / CGFloat(tabs!.count)) / 3.0,
            tabProgress: $tabProgress
        ) {
            ForEach(tabs!, id: \.rawValue) { filter in
                //                    VStack(spacing: 16) {
                let filterValue = filter.rawValue
                
                filter.image
                    .frame(16)
                    .foregroundStyle(selectedTab == filterValue ? Color.theme.iconPrimary : Color.theme.iconSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(.rect)
                    .onTapGesture {
                        haptics(.light)
                        withAnimation(.spring) {
                            coordinator.selectedTab = filterValue
                        }
                    }
            }
        }
    }
    
    // MARK: - Helpers
    private var snapUp: some Gesture {
        DragGesture()
            .onChanged { value in
                guard coordinator.smallHeader, !coordinator.isScrolling, coordinator.canGoUp[selectedTab ?? 0] ?? false else { return }
                if value.translation.height > 10, abs(value.translation.width) < 20 {
                    coordinator.isScrolling = true
                    coordinator.scrollToTop.toggle()
                    haptics(.rigid)
                    withAnimation(.easeInOut(duration: 0.25), completionCriteria: .logicallyComplete) {
                        coordinator.smallHeader = false
                    } completion: {
                        coordinator.smallHeaderAnimationComplete = false
                    }
                }
            }
            .onEnded { _ in
                coordinator.isScrolling = false
            }
    }
    
    private var snapDown: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !coordinator.smallHeader else { return }
                if value.translation.height < -10, abs(value.translation.width) < 20 {
                    coordinator.isScrolling = true
                    if !panDisabled {
                        tabCoordinator.pan = .edgePan
                    }
                    haptics(.light)
                    withAnimation(.easeInOut(duration: 0.25), completionCriteria: .logicallyComplete) {
                        coordinator.smallHeader = true
                    } completion: {
                        coordinator.smallHeaderAnimationComplete = true
                    }
                } else if value.translation.height > 10, abs(value.translation.width) < 20 {
                    if !panDisabled {
                        tabCoordinator.pan = .edgePan // prevent pan to go back when trying to scroll up
                    }
                }
            }
            .onEnded { _ in
                coordinator.isScrolling = false
                if !panDisabled {
                    tabCoordinator.pan = .pan
                }
            }
    }
}

struct TabContent<Content: View>: View {
    @Environment(ProfileTabSwitcherCoordinator.self) private var coordinator
    let id: Int
    let content: () -> Content
    
    @State private var scrollOffset: CGFloat = 0
        
    var body: some View {
        @Bindable var bindableVM = coordinator
        
        if #available(iOS 18.0, *) {
            // navigationlink during scrolling seems to only happen in iOS 18
            TabContentHelper()
                .onScrollPhaseChange { oldPhase, newPhase in
                    if newPhase == .idle, oldPhase != .idle {
                        coordinator.isScrolling = false
                    } else if oldPhase == .idle, newPhase != .idle {
                        coordinator.isScrolling = true
                    }
                } // TODO: still need to recognize if scrolling for iOS 17 for drag through to top shouldn't snap back up
        } else {
            TabContentHelper()
        }
        
//        TabContentHelper()
//            .isInteracting($bindableVM.isScrolling)
    }
    
    @ViewBuilder
    private func TabContentHelper() -> some View {
        ScrollViewReader { reader in
            ScrollView {
                ZStack {
                    Spacer().containerRelativeFrame([.horizontal, .vertical]) // center content (for pagination states). will need to frameTop for items
                    
                    content()
                        .id("content")
                        
                        .onChange(of: coordinator.scrollToTop) {
                            reader.scrollTo("content", anchor: .top)
                        }
                }
                .offsetY { value in
                    guard coordinator.canGoUp[id] != (value == 0) else { return }
                    coordinator.canGoUp[id] = (value == 0)
                }
            }
            .disableBounce()
            .scrollDisabled(!coordinator.smallHeaderAnimationComplete)
        }
        .containerRelativeFrame(.horizontal)
        .id(id)
    }
}
