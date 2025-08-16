//
////
////  ProfileTabSwitcher.swift
////  Clique
////
////  Created by Rod Tavangar on 12/5/24.
////
//
//import SwiftUI
//import ScalingHeaderScrollView
//import BezelKit
//
//// TODO: content heights and clean up. scalingheaderscrollview height clipped to selected filter height. also tab bar in collapsed mode doesn't work
//
//struct ProfileTabSwitcher<Tab: ProfileTabFilter, SmallHeader: View, LargeHeader: View, Content: View>: View {
//    @Environment(\.safeAreaInsets) private var safeAreaInsets
//    @EnvironmentObject private var tabCoordinator: TabViewCoordinator
//    @StateObject private var profileTabSwitcherCoordinator = ProfileTabSwitcherCoordinator()
//    
//    @State private var selectedFilter: Int? = 0
//    @State private var scrollProgress: CGFloat = 0
//    @State private var scrollYOffset: CGFloat = 0
//    
//    @State private var scrollStopTimer: Timer?
//    @State private var earlyDragging: Bool = false
//    
//    let smallHeaderView: SmallHeader
//    let largeHeaderView: LargeHeader
//    let content: (Int) -> Content
//    let dismiss: () -> Void
//    let tabs: [Tab]
//    let ignoresSafeArea: Bool
//    
//    @State private var smallHeaderHeight: CGFloat = 0
//    @State private var largeHeaderHeight: CGFloat = 0
//    @State private var tabBarHeight: CGFloat = 0
//    
//    @State private var showMainView: Bool = true
//    
//    @State private var tabProgress: CGFloat = 0
//    
//    private var transitionToTop: Bool {
//        profileTabSwitcherCoordinator.transitionToTop
//    }
//    
//    private var showCollapsedView: Bool {
//        profileTabSwitcherCoordinator.showCollapsedView
//    }
//    
//    //    private var showCollapsedView: Bool {
//    //        profileTabSwitcherCoordinator.showCollapsedView
//    //    }
//    
//    private var headerState: SnapHeaderState {
//        profileTabSwitcherCoordinator.headerState ?? .collapsed
//    }
//    
//    private var scrollHeight: CGFloat {
//        largeHeaderHeight - smallHeaderHeight
//    }
//    
//    private var showSmallHeader: Bool {
//        profileTabSwitcherCoordinator.showSmallHeader
//    }
//    
//    init(
//        smallHeaderView: SmallHeader,
//        largeHeaderView: LargeHeader,
//        dismiss: (() -> Void)? = nil,
//        tabs: [Tab],
//        ignoresSafeArea: Bool? = true,
//        @ViewBuilder content: @escaping (Int) -> Content
//    ) {
//        //        print("hi")
//        // TODO: this whole thing should only initialize once. that will get rid of the need for abs
//        self.smallHeaderView = smallHeaderView
//        self.largeHeaderView = largeHeaderView
//        
//        self.dismiss = dismiss ?? {}
//        self.tabs = tabs
//        self.ignoresSafeArea = ignoresSafeArea ?? false
//        self.content = content
//    }
//    
//    // scale animation presentation background solution
//    //    private func adjustment(width: CGFloat) -> CGFloat {
//    //        guard width != 0 else { return 0 }
//    //        switch tabCoordinator.dismissDragProgress / width {
//    //        case 0...0.25: return 3.55
//    //        case 0.25...0.5: return 2.8
//    //        case 0.5...0.75: return 1.05
//    //        case 0.75...1: return 0.4
//    //        default: return -1
//    //        }
//    //    }
//    
//    var body: some View {
//        ZStack(alignment: .top) {
//            ZStack(alignment: .topLeading) {
//                // TODO: progress / width percent for function of clipshape
//                //                    Rectangle()
//                //                        .fill(.background)
//                //                        .frame(
//                //                            width: geo.size.width / 2,
//                //                            height: max(
//                //                                0, // Prevent negative heights
//                //                                ((geo.size.height * (1 - Constants.transitionShrinkFactor)) / 2) *
//                //                                (1 - min(1, max(0, tabCoordinator.dismissDragProgress / geo.size.width)))
//                //                            ) + adjustment(width: geo.size.width)
//                // shouldn't need these max()
//                //                        ) // height - (height * progress)
//                // height (1 - progress)
//                
//                
////                if showSmallHeader {
//////                    Collapsed(width: UIScreen.width)
////                    Rectangle()
////                        .frame(height: 300)
////                        .onTapGesture {
////                            profileTabSwitcherCoordinator.showSmallHeader = false
////                        }
////                } else {
////                    Expanded(width: UIScreen.width)
////                }
////                
//                ZStack {
//                    Expanded(width: UIScreen.width)
//                        .opacity(profileTabSwitcherCoordinator.showTest ? 0 : 1)
//                    
////                    Rectangle()
////                        .frame(height: 300)
////                        .onTapGesture {
////                            profileTabSwitcherCoordinator.showTest = false
////                        }
//                    Collapsed(width: UIScreen.width)
//                        .opacity(profileTabSwitcherCoordinator.showTest ? 1 : 0)
//                }
//                
//                smallHeaderView
//                    .opacity(max(0, min(1, (scrollProgress - 0.75) * 4.0)))
//                
//            }
//        }
//        .if(ignoresSafeArea) { view in
//            view
//                .ignoresSafeArea(edges: .top)
//        }
//        .primaryBackground()
//        //        .padding(.top, ignoresSafeArea ? -safeAreaInsets.top : 0) // ignoring safe area messes with the paging HStack
//        .onChange(of: tabCoordinator.sameTabTapped) {
//            if tabCoordinator.sameTabTapped {
//                dismiss()
//            }
//        }
//        .onChange(of: selectedFilter) {
////            print(selectedFilter)
//        }
//    }
//    
//    @ViewBuilder
//    private func Expanded(width: CGFloat) -> some View {
//        ScalingHeaderScrollView {
//            VStack(spacing: 0) {
//                ZStack(alignment: .top) {
//                    largeHeaderView
//                    //                        .opacity(1 - max(0, min(1, (scrollProgress - 0.75) * 4.0)))
//                        .opacity(1)
//                        .if(largeHeaderHeight == 0) { view in
//                            view
//                                .getSize { size in
//                                    largeHeaderHeight = size.height
//                                }
//                        }
//                    
//                    smallHeaderView
//                    //                        .opacity(max(0, min(1, (scrollProgress - 0.75) * 4.0)))
//                        .if(smallHeaderHeight == 0) { view in
//                            view
//                                .getSize { size in
//                                    smallHeaderHeight = size.height
//                                }
//                        }
//                        .hidden()
//                }
//                
//                Tabs()
//            }
//        } content: {
//            TabsContent(width, collapsed: false)
//            //            Rectangle()
//            //                .frame(height: 800)
//            //                    .opacity(hideContent ? 0 : 1)
//        }
//        .collapseProgress($scrollProgress)
//        .height(min: smallHeaderHeight + tabBarHeight,
//                max: largeHeaderHeight + tabBarHeight)
//        .headerSnappingPositions(snapPositions: [0, 1])
//        .setHeaderSnapMode(.afterFinishAccelerating)
//        .scrollOffset($scrollYOffset)
//        .snapHeaderToState($profileTabSwitcherCoordinator.headerState, animated: false)
//        //        .scrollToTop(resetScroll: $profileTabSwitcherCoordinator.goBackUp)
//        .scrollIndicators(.hidden)
//        .if(!showSmallHeader) { view in
//            view
//                .onChange(of: scrollYOffset) { oldValue, newValue in
//                    if !profileTabSwitcherCoordinator.showTest, scrollProgress > 0.99, !profileTabSwitcherCoordinator.goBackUp {
////                        print("here", oldValue, newValue)
//                        handleScrollChange(oldValue: oldValue, newValue: newValue)
//                    }
//                }
//        }
//        .onChange(of: profileTabSwitcherCoordinator.showTest) { oldValue, newValue in
//            if oldValue == true, newValue == false {
//                profileTabSwitcherCoordinator.headerState = .expanded
//                profileTabSwitcherCoordinator.showTest = false
//                // literally no clue
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    profileTabSwitcherCoordinator.goBackUp = false
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private func Collapsed(width: CGFloat) -> some View {
//        VStack(spacing: 0) {
//            smallHeaderView
//                .contentShape(.rect)
//            //                .onTapGesture {
//            //                    withAnimation {
//            //                        profileTabSwitcherCoordinator.showSmallHeader = false
//            //                    }
//            //                }
//            //                .opacity(showSmallHeader ? 1 : 0)
//            
//            Tabs()
//                .contentShape(.rect)
////                .border(.red)
//            
//            TabsContent(width, collapsed: true)
//            //                .opacity(hideContent ? 1 : 0)
//        }
//    }
//    
//    private func handleScrollChange(oldValue: CGFloat, newValue: CGFloat) {
//        if !profileTabSwitcherCoordinator.isScrolling { // scrollview lags otherwise
//            profileTabSwitcherCoordinator.isScrolling = true
//        }
//        scrollStopTimer?.invalidate() // Cancel any existing timer
//        scrollStopTimer = Timer.scheduledTimer(withTimeInterval: 0.000001, repeats: false) { _ in
//            // Timer fires only if no new changes occur within the interval
//            onScrollStopped()
//        }
//    }
//    
//    private func onScrollStopped() {
//        if scrollProgress > 0.99 { // snap goes to 0.999523582658409
//                        
//            profileTabSwitcherCoordinator.scrollYOffset = scrollYOffset - scrollHeight
//            profileTabSwitcherCoordinator.scrolledTabId = selectedFilter ?? 0
////            profileTabSwitcherCoordinator.showSmallHeader = true
//            profileTabSwitcherCoordinator.showTest = true
////            profileTabSwitcherCoordinator.showCollapsedView = true
//            profileTabSwitcherCoordinator.goBackUp = true
////            print("herecol")
//            profileTabSwitcherCoordinator.headerState = .collapsed
//            
//            
//            //
//            //            // reset
////                        scrollProgress = 0
//        }
//        profileTabSwitcherCoordinator.isScrolling = false
//    }
//    
//    @ViewBuilder
//    private func TabsContent(_ width: CGFloat, collapsed: Bool) -> some View {
//        ScrollViewReader { reader in
//            ScrollView(.horizontal) {
//                LazyHStack(alignment: .top, spacing: 0) {
//                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, _ in
//                        Group {
//                            if collapsed {
//                                TabContent2(id: index) {
//                                    content(index)
//                                }
//                                    .environmentObject(profileTabSwitcherCoordinator)
//                            } else {
//                                TabContent(id: index) {
//                                    content(index)
//                                }
//                                    .environmentObject(profileTabSwitcherCoordinator)
//                            }
//                        }
//                        .id(index)
//                        .containerRelativeFrame(.horizontal)
//                    }
//                }
//                .scrollTargetLayout()
//                .offsetX { value in
//                    let progress = -value / (width * CGFloat(tabs.count))
//                    tabProgress = max(min(progress, 1), 0)
//                }
//            }
//            .scrollIndicators(.hidden)
//            .scrollTargetBehavior(.paging)
//            .scrollPosition(id: $selectedFilter)
//            .scrollClipDisabled()
//            //        .offsetY { value in
//            //            let progress = value
//            //            profileTabSwitcherCoordinator.tabProgress = max(min(progress, 1), 0)
//            //        }
//            //        .onChange(of: scrollYOffset) { oldValue, newValue in
//            //            handleScrollChange(oldValue: oldValue, newValue: newValue)
//            //        }
//            .onScrollPhaseChange { oldPhase, newPhase in
//                if newPhase == .interacting {
//                    profileTabSwitcherCoordinator.isScrolling = true
//                } else if oldPhase != .idle, newPhase == .idle {
//                    profileTabSwitcherCoordinator.isScrolling = false
//                }
//            }
//            .onChange(of: selectedFilter) {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // sync bug (this file is my downfall)
//                    reader.scrollTo(selectedFilter, anchor: .top)
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder
//    func Tabs() -> some View {
//        let indicatorHeight = 2.5
//        ZStack(alignment: .topLeading) {
//            HStack(spacing: 0) {
//                ForEach(tabs) { filter in
//                    //                    VStack(spacing: 16) {
//                    let filterValue = filter.rawValue
//                    
//                    Image(filter.icon)
//                        .icon(color: selectedFilter == filterValue ? Color.theme.iconPrimary : Color.theme.iconSecondary, size: 16)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 16)
//                        .contentShape(.rect)
//                        .onTapGesture {
//                            withAnimation(.spring) {
//                                selectedFilter = filterValue
//                                //                            haptics(.light)
//                            }
//                        }
//                }
//            }
//            
//            Divider()
//                .offset(y: indicatorHeight / 2)
//            
//            GeometryReader { geo in
//                RoundedRectangle(cornerRadius: 10)
//                    .foregroundStyle(Color.theme.iconPrimary)
//                    .frame(width: 47)
//                    .onAppear { // hack since indicator doesn't show when first page in navstack
//                        if selectedFilter == 0 {
//                            tabProgress = 0
//                        }
//                    }
//                    .frame(width: geo.size.width / 3, height: indicatorHeight)
//                    .offset(x: tabProgress * (geo.size.width))
//            }
//        }
//        .if(tabBarHeight == 0) { view in
//            view
//                .getSize { size in
//                    tabBarHeight = size.height
//                }
//        }
//        .frame(height: 48)
//        .primaryBackground()
//    }
//}
//
//struct TabContent<Content: View>: View {
//    @EnvironmentObject private var profileTabSwitcherCoordinator: ProfileTabSwitcherCoordinator
//    
//    @State private var position = ScrollPosition(edge: .top)
//    @State private var isScrolling: Bool = false
//    
//    let id: Int
//    let content: () -> Content
//    
//    var body: some View {
////        Group {
////            if profileTabSwitcherCoordinator.collapsedMode {
////                ScrollView {
////                    content()
////                        .offsetY { value in
////                            if !isScrolling, value >= 0 {
////                                isScrolling = true
////                            } else if value >= 0 {
////                                isScrolling = false
////                                //                                profileTabSwitcherCoordinator.goBackUp = true
////                                //                                profileTabSwitcherCoordinator.showSmallHeader = false
////                                profileTabSwitcherCoordinator.showCollapsedView = false
////                                profileTabSwitcherCoordinator.transitionToTop = true
////                            }
////                        }
////                }
////                .scrollPosition($position)
////                .if(profileTabSwitcherCoordinator.scrolledTabId == id) { view in
////                    view
////                        .onAppear {
////                            position.scrollTo(x: 0, y: profileTabSwitcherCoordinator.scrollYOffset)
////                        }
////                }
////                .onScrollPhaseChange { oldPhase, newPhase in
////                    if newPhase == .interacting {
////                        profileTabSwitcherCoordinator.isScrolling = true
////                    } else if oldPhase != .idle, newPhase == .idle {
////                        profileTabSwitcherCoordinator.isScrolling = false
////                    }
////                }
////            } else {
////                content()
////            }
////        }
//        content()
//    }
//}
//
//struct TabContent2<Content: View>: View {
//    @EnvironmentObject private var profileTabSwitcherCoordinator: ProfileTabSwitcherCoordinator
//    
//    let id: Int
//    let content: () -> Content
//    
//    @State private var position = ScrollPosition(edge: .top)
//    @State private var isScrolling: Bool = false
//    
//    var body: some View {
//        ScrollView {
//            content()
//                .offsetY { value in
//                    if !isScrolling, value >= 0 {
//                        isScrolling = true
//                    } else if value >= 0 {
//                        isScrolling = false
////                        profileTabSwitcherCoordinator.goBackUp = false
//                        profileTabSwitcherCoordinator.showTest = false
//                        //                                        profileTabSwitcherCoordinator.showCollapsedView = false
//                        profileTabSwitcherCoordinator.transitionToTop = true
//                    }
//                }
//        }
//        .scrollPosition($position)
//        .if(profileTabSwitcherCoordinator.scrolledTabId == id && profileTabSwitcherCoordinator.showTest) { view in
//            view
//                .onAppear { // when this hits true
//                    position.scrollTo(y: profileTabSwitcherCoordinator.scrollYOffset)
//                }
//        }
//        .onChange(of: profileTabSwitcherCoordinator.showTest) { oldValue, newValue in
//            if oldValue == true, newValue == false { // went back up
//                position.scrollTo(y: 0)
//            }
//        }
//        .onScrollPhaseChange { oldPhase, newPhase in
//            if newPhase == .interacting {
//                profileTabSwitcherCoordinator.isScrolling = true
//            } else if oldPhase != .idle, newPhase == .idle {
//                profileTabSwitcherCoordinator.isScrolling = false
//            }
//        }
//    }
//}
