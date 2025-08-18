//
//  HeaderPageScrollView.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI

/// Configuration for a single page/tab in the HeaderPageScrollView.
///
/// This struct defines the display properties for each tab in the scrolling
/// interface, supporting both text-based and symbol-based representations.
///
/// ## Usage
/// ```swift
/// PageLabel(title: "Photos", symbolImage: "photo")
/// PageLabel(title: "Videos", symbolImage: "video")
/// ```
///
/// - Note: symbolImage can be either SF Symbol name or custom image asset name
struct PageLabel {
    /// Display title for the tab
    var title: String
    /// Icon name (SF Symbol or custom image)
    var symbolImage: String
}

/// Result builder for creating arrays of PageLabel in a declarative syntax.
///
/// This builder enables clean, SwiftUI-style syntax for defining multiple
/// page labels without explicitly creating arrays.
///
/// ## Usage Example
/// ```swift
/// HeaderPageScrollView(
///     // ...
///     labels: {
///         PageLabel(title: "Photos", symbolImage: "photo")
///         PageLabel(title: "Videos", symbolImage: "video")
///         PageLabel(title: "Collections", symbolImage: "square.grid.2x2")
///     }
/// )
/// ```
@resultBuilder
struct PageLabelBuilder {
    static func buildBlock(_ components: PageLabel...) -> [PageLabel] {
        components.compactMap({ $0 })
    }
}

/// Advanced scrolling component with synchronized header and tabbed content.
///
/// This component creates a sophisticated scrolling interface similar to social media
/// profile screens, featuring a sticky header that collapses/expands and synchronized
/// scroll behavior across multiple tabbed pages.
///
/// ## Key Features
/// - **Synchronized Scrolling**: All tab pages scroll in harmony
/// - **Sticky Header**: Header collapses and expands based on scroll position
/// - **Smooth Transitions**: Fluid animations between tabs and scroll states
/// - **Navigation Integration**: Smart pan gesture handling to prevent conflicts
/// - **Scroll State Tracking**: Exposes scrolling state via AppCoordinator for navigation control
/// - **Performance Optimized**: Lazy loading and efficient scroll management
/// - **Customizable**: Flexible header and page content with builder patterns
///
/// ## Architecture
/// ```
/// HeaderPageScrollView
/// ├── Horizontal ScrollView (tab switching)
/// │   └── HStack of PageScrollView instances
/// └── Each PageScrollView contains:
///     ├── LazyVStack with pinned headers
///     ├── Sticky header content
///     ├── Custom tab bar
///     └── Page-specific content
/// ```
///
/// ## Scroll Synchronization
/// The component maintains scroll position synchronization by:
/// 1. **Tracking Geometry**: Monitoring scroll positions across all pages
/// 2. **Cross-Page Updates**: Syncing scroll offsets when switching tabs
/// 3. **Header Height Awareness**: Coordinating around sticky header behavior
/// 4. **Pinned State Synchronization**: When the tab bar becomes pinned, all tabs are pre-scrolled to the pinned position
/// 5. **Tab Switch Consistency**: Ensures newly active tabs maintain the correct scroll position
/// 6. **Performance Optimization**: Only updating when necessary to maintain smooth transitions
///
/// ## Navigation Integration
/// Special handling for navigation conflicts:
/// - **Edge Pan Mode**: Switches to edge-only pan during horizontal scrolling
/// - **Header Gestures**: Blocks tab switching during header interactions
/// - **Smart Restoration**: Restores full pan navigation when appropriate
/// - **Scroll State Broadcasting**: Updates `AppCoordinator.isHeaderPageScrolling` to allow
///   child views to disable navigation during scroll operations
///
/// ## Usage Example
/// ```swift
/// HeaderPageScrollView(
///     displaysSymbols: true,
///     header: {
///         UserProfileHeader(user: user)
///     },
///     labels: {
///         PageLabel(title: "Posts", symbolImage: "photo")
///         PageLabel(title: "Collections", symbolImage: "square.grid.2x2")
///     },
///     pages: {
///         UserPostsView()
///         UserCollectionsView()
///     },
///     onRefresh: {
///         await refreshUserData()
///     }
/// )
/// ```
///
/// ## Preventing Navigation During Scrolling
/// Child views should disable navigation when scrolling is active:
/// ```swift
/// struct UserPostsView: View {
///     @Environment(AppCoordinator.self) private var appCoordinator
///     
///     var body: some View {
///         NavigationLink(value: post) {
///             PostCell(post: post)
///         }
///         .buttonStyle(.noHighlight)
///         .disabled(appCoordinator.isHeaderPageScrolling)
///     }
/// }
/// ```
///
/// ## Performance Considerations
/// - Uses `LazyVStack` for efficient content loading
/// - Implements smart scroll position caching
/// - Minimizes layout calculations through geometry tracking
/// - Optimizes for smooth 60fps scrolling
///
/// - Important: Requires iOS 18+ for advanced scroll APIs
/// - Note: Integrates with ``TabViewCoordinator`` for navigation harmony
@available(iOS 18, *)
struct HeaderPageScrollView<Header: View, Pages: View>: View {
    // MARK: - Environment
    /// System safe area insets for proper layout
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    /// App-wide coordinator for context-aware behaviors
    @Environment(AppCoordinator.self) private var appCoordinator
    /// Tab navigation coordinator for pan gesture management
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    
    // MARK: - Configuration
    /// Whether to display symbols instead of text in tab bar
    var displaysSymbols: Bool = false
    /// Whether to ignore top safe area for full-screen header
    var ignoreTopSafeArea: Bool = false
    /// The header content that sticks and collapses
    var header: Header
    /// Tab configuration for the page switcher
    var labels: [PageLabel]
    /// The page content views
    var pages: Pages
    /// Callback for pull-to-refresh functionality
    var onRefresh: () -> ()
    
    /// Initializes the HeaderPageScrollView with configuration and content builders.
    ///
    /// This initializer sets up the complete scrolling interface with all necessary
    /// components and prepares internal state for scroll synchronization.
    ///
    /// - Parameters:
    ///   - displaysSymbols: Whether tab bar shows symbols (true) or text (false)
    ///   - ignoreTopSafeArea: Whether header extends into top safe area
    ///   - header: Builder for the sticky header content
    ///   - labels: Builder for tab configuration using ``PageLabelBuilder``
    ///   - pages: Builder for page content views
    ///   - onRefresh: Optional pull-to-refresh callback
    ///
    /// ## Initialization Process
    /// 1. **Configuration Setup**: Stores display and layout preferences
    /// 2. **Content Building**: Executes builders to create views and labels
    /// 3. **State Preparation**: Initializes scroll tracking arrays
    /// 4. **Geometry Setup**: Prepares scroll position and geometry tracking
    ///
    /// ## State Management
    /// The initializer creates tracking arrays based on the number of labels:
    /// - Scroll positions for each page
    /// - Geometry trackers for each page
    /// - Performance optimization through pre-allocation
    init(
        displaysSymbols: Bool,
        ignoreTopSafeArea: Bool = false,
        @ViewBuilder header: @escaping () -> Header,
        @PageLabelBuilder labels: @escaping () -> [PageLabel],
        @ViewBuilder pages: @escaping () -> Pages,
        onRefresh: @escaping () -> () = {  }
    ) {
        self.displaysSymbols = displaysSymbols
        self.ignoreTopSafeArea = ignoreTopSafeArea
        self.header = header()
        self.labels = labels()
        self.pages = pages()
        self.onRefresh = onRefresh
        
        let count = labels().count
        self._scrollPositions = .init(initialValue: .init(repeating: .init(), count: count))
        self._scrollGeometries = .init(initialValue: .init(repeating: .init(), count: count))
        self._verticalScrollPhases = .init(initialValue: .init(repeating: .idle, count: count))
        self._hadVerticalInteraction = .init(initialValue: .init(repeating: false, count: count))
    }
    
    /// View Properties
    @State private var activeTab: String?
    @State private var headerHeight: CGFloat = 0
    @State private var scrollGeometries: [ScrollGeometry]
    @State private var scrollPositions: [ScrollPosition]
    /// Main Scroll Properties
    @State private var mainScrollDisabled: Bool = false
    @State private var mainScrollPhase: ScrollPhase = .idle
    @State private var mainScrollGeometry: ScrollGeometry = .init()
    /// Track if tab bar is pinned
    @State private var isTabBarPinned: Bool = false
    /// Track vertical scroll phases for each page
    @State private var verticalScrollPhases: [ScrollPhase] = []
    /// Track if we had a user interaction for vertical scrolling
    @State private var hadVerticalInteraction: [Bool] = []
    
    
    // MARK: Body
    var body: some View {
        GeometryReader {
            let size = $0.size
            
            ScrollView(.horizontal) {
                /// Using HStack allows us to maintain references to other scrollviews, enabling us to update them when necessary.
                HStack(spacing: 0) {
                    Group(subviews: pages) { collection in
                        /// Checking both collection and labels match with each other
                        if collection.count != labels.count {
                            Text("Tabviews and labels does not match!")
                                .frame(width: size.width, height: size.height)
                        } else {
                            ForEach(labels, id: \.title) { label in
                                PageScrollView(label: label, size: size, collection: collection)
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $activeTab)
            .scrollIndicators(.hidden)
            .scrollDisabled(mainScrollDisabled)
            /// Disabling Interaction when scroll view is animating to avoid unintentional taps!
            .allowsHitTesting(mainScrollPhase == .idle)
            .onScrollPhaseChange({ oldPhase, newPhase in
                mainScrollPhase = newPhase
                
                // Track horizontal scrolling state
                if newPhase == .idle && oldPhase != .idle {
                    appCoordinator.isHeaderPageScrolling = false
                } else if oldPhase == .idle && newPhase != .idle {
                    appCoordinator.isHeaderPageScrolling = true
                }
                
                // Switch to edge pan during horizontal scrolling
                if newPhase != .idle && tabViewCoordinator.pan != .edgePan {
                    tabViewCoordinator.pan = .edgePan
                } else if newPhase == .idle && tabViewCoordinator.pan != .pan {
                    // Restore pan when scrolling ends
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if tabViewCoordinator.pan != .pan {
                            tabViewCoordinator.pan = .pan
                        }
                    }
                }
            })
            .onScrollGeometryChange(for: ScrollGeometry.self, of: {
                $0
            }, action: { oldValue, newValue in
                mainScrollGeometry = newValue
            })
            .mask {
                Rectangle()
                    .ignoresSafeArea(.all, edges: isTabBarPinned ? .bottom : .all)
            }
            .onAppear {
                /// Setting up Initial Tab Value
                guard activeTab == nil else { return }
                
                activeTab = labels.first?.title
            }
            .onChange(of: isTabBarPinned) { oldValue, newValue in
                // When tab bar becomes pinned, sync all tabs to the pinned position
                if newValue {
                    for index in labels.indices {
                        let currentOffset = scrollGeometries[index].offsetY
                        if currentOffset < headerHeight {
                            scrollPositions[index].scrollTo(y: headerHeight)
                        }
                    }
                }
            }
            .onChange(of: activeTab) { oldValue, newValue in
                // Ensure the newly active tab maintains the pinned scroll position when switching tabs
                if isTabBarPinned,
                   let newTab = newValue,
                   let index = labels.firstIndex(where: { $0.title == newTab }) {
                    // If the new tab isn't scrolled to pin position, scroll it there
                    let currentOffset = scrollGeometries[index].offsetY
                    if currentOffset < headerHeight {
                        scrollPositions[index].scrollTo(y: headerHeight)
                    }
                }
            }
        }
        .background(Color.theme.surfacesBackgroundPrimary, ignoresSafeAreaEdges: ignoreTopSafeArea ? .top : [])
    }
    
    // MARK: Page Scroll View
    @ViewBuilder private func PageScrollView(label: PageLabel, size: CGSize, collection: SubviewsCollection) -> some View {
        let index = labels.firstIndex(where: { $0.title == label.title }) ?? 0
        
        ScrollView(.vertical) {
            /// Using LazyVstack for Optimizing Performance as it LazyLoads Views!
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                /// Always render header to prevent flashing
                ZStack {
                    header
                        /// Making it as a sticky one so that it won't move left or right when interacting!
                        .visualEffect({ content, proxy in
                            content
                                .offset(x: -proxy.frame(in: .scrollView(axis: .horizontal)).minX)
                        })
                        .offset(y: ignoreTopSafeArea ? -safeAreaInsets.top : 0)
                        .onGeometryChange(for: CGFloat.self) {
                            $0.size.height
                        } action: { newValue in
                            headerHeight = newValue
                        }
                        .opacity(activeTab == label.title ? 1 : 0)
                        .animation(.none, value: activeTab)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // Block tab switching for any drag on the header
                            mainScrollDisabled = true
                            // Don't switch to edgePan - keep full pan mode
                            // This allows the swipe to fall through to navigation
                        }
                        .onEnded { _ in
                            mainScrollDisabled = false
                        }
                )

                
                /// Using Pinned Views to actually pin our tab bar at the top!
                Section {
                    collection[index]
                        .padding(.top, 16)
                        /// Let's make it to be scrollable to the top even if the view does not have enough content
                        /// 40 - Tab Bar Size, -5 is given so that it will not reset scrollviews when it's bounces!
                        .frame(minHeight: size.height - 35, alignment: .top)
                } header: {
                    /// Always render tab bar to prevent flashing
                    ZStack {
                        CustomTabBar
                            .visualEffect({ content, proxy in
                                content
                                    .offset(x: -proxy.frame(in: .scrollView(axis: .horizontal)).minX)
                            })
                            .opacity(activeTab == label.title ? 1 : 0)
                            .animation(.none, value: activeTab)
                    }
                    .simultaneousGesture(horizontalScrollDisableGesture)
                }
            }
        }
        .onScrollGeometryChange(for: ScrollGeometry.self, of: {
            $0
        }, action: { oldValue, newValue in
            scrollGeometries[index] = newValue
            
            // Only update pinned state if we're actively scrolling vertically with user interaction
            if activeTab == label.title && hadVerticalInteraction[index] && verticalScrollPhases[index] != .idle {
                isTabBarPinned = newValue.offsetY >= headerHeight
            }
            
            if newValue.offsetY < 0 {
                resetScrollViews(label)
            }
        })
        .scrollPosition($scrollPositions[index])
        .onScrollPhaseChange { oldPhase, newPhase in
            let geometry = scrollGeometries[index]
            let maxOffset = min(geometry.offsetY, headerHeight)
            
            // Track vertical scroll phase for this page
            verticalScrollPhases[index] = newPhase
            
            // Track if this is user-initiated vertical scrolling
            if newPhase == .interacting {
                hadVerticalInteraction[index] = true
            } else if newPhase == .idle {
                hadVerticalInteraction[index] = false
            }
            
            // Track vertical scrolling state
            if activeTab == label.title {
                if newPhase == .idle && oldPhase != .idle {
                    appCoordinator.isHeaderPageScrolling = false
                } else if oldPhase == .idle && newPhase != .idle {
                    appCoordinator.isHeaderPageScrolling = true
                }
            }
            
            if newPhase == .idle && maxOffset <= headerHeight {
                updateOtherScrollViews(label, to: maxOffset)
            }
            
            /// Fail-Safe
            if newPhase == .idle && mainScrollDisabled {
                mainScrollDisabled = false
            }
        }
        .frame(width: size.width)
        .scrollClipDisabled()
        .refreshable { onRefresh() }
        .zIndex(activeTab == label.title ? 1000 : 0)
    }
    
    // MARK: Custom Tab Bar
    private var CustomTabBar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 0) {
                    ForEach(labels, id: \.title) { label in
                        Group {
                            if displaysSymbols {
                                // Check if it's a system symbol or custom image
                                if UIImage(systemName: label.symbolImage) != nil {
                                    Image(systemName: label.symbolImage)
                                } else {
                                    Image(label.symbolImage)
                                        .resizable()
                                        .renderingMode(.template)
                                }
                            } else {
                                Text(label.title)
                            }
                        }
                        .frame(16)
                        .foregroundStyle(activeTab == label.title ? Color.theme.iconPrimary : Color.theme.iconSecondary)
                        .maxWidth()
                        .padding(.bottom, 4)
                        .contentShape(.rect)
                        .onTapGesture {
                            haptics(.light)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                activeTab = label.title
                            }
                        }
                    }
                }
                .maxHeight()
                
                Divider()
                    .overlay {
                        GeometryReader { geo in
                            let progress = max(min(mainScrollGeometry.offsetX / mainScrollGeometry.containerSize.width, CGFloat(labels.count - 1)), 0)
                            
                            HStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.theme.iconPrimary.shadow(.drop(color: Color.theme.navbarShadow, radius: 5)))
                                    .frame(width: geo.size.width / CGFloat(labels.count) / 3.0, height: Constants.tabBarIndicatorHeight)
                                    .containerRelativeFrame(.horizontal) { value, _ in
                                        return value / CGFloat(labels.count)
                                    }
                                    .visualEffect { content, proxy in
                                        content
                                            .offset(x: proxy.size.width * progress, y: -1)
                                    }
                            }
                            .frame(width: geo.size.width / CGFloat(labels.count), height: Constants.tabBarIndicatorHeight)
                        }
                    }
            }
        }
        .primaryBackground()
    }
    
    var horizontalScrollDisableGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Check if this is a horizontal swipe
                if abs(value.translation.width) > abs(value.translation.height) {
                    // Switch to edge pan to prevent navigation conflict
                    if tabViewCoordinator.pan != .edgePan {
                        tabViewCoordinator.pan = .edgePan
                    }
                }
                mainScrollDisabled = true
            }.onEnded { _ in
                mainScrollDisabled = false
                // Restore pan navigation after gesture ends
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if tabViewCoordinator.pan != .pan {
                        tabViewCoordinator.pan = .pan
                    }
                }
            }
    }
}

@available(iOS 18, *)
private extension HeaderPageScrollView {
    /// Reset's Page ScrollView to it's Initial Position
    func resetScrollViews(_ from: PageLabel) {
        for index in labels.indices {
            let label = labels[index]
            
            if label.title != from.title {
                scrollPositions[index].scrollTo(y: 0)
            }
        }
    }
    
    /// Update Other scrollviews to match up with the current scroll view till reaching it's header height
    func updateOtherScrollViews(_ from: PageLabel, to: CGFloat) {
        for index in labels.indices {
            let label = labels[index]
            let offset = scrollGeometries[index].offsetY
            
            let wantsUpdate = offset < headerHeight || to < headerHeight
            
            if wantsUpdate && label.title != from.title {
                scrollPositions[index].scrollTo(y: to)
            }
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension ScrollGeometry {
    init() {
        self.init(contentOffset: .zero, contentSize: .zero, contentInsets: .init(.zero), containerSize: .zero)
    }
    
    var offsetY: CGFloat {
        contentOffset.y + contentInsets.top
    }
    
    var offsetX: CGFloat {
        contentOffset.x + contentInsets.leading
    }
}
