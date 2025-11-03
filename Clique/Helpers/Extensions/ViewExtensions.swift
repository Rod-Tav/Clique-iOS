//
//  ViewExtensions.swift
//  Clique
//
//  Created by Rod Tavangar on 12/13/24.
//

import SwiftUI

extension View {
    func feedCellBottomOverlayModifiers() -> some View {
        self
            .padding(12)
            .background(Gradients.feedCellCommentBg)
            .roundCorners(8)
    }
    
    func roundCorners(_ size: CGFloat) -> some View {
        self
            .clipShape(.rect(cornerRadius: size))
    }
}

extension View {
    func textPrimary() -> some View {
        self
            .foregroundStyle(Color.theme.textPrimary)
    }
    
    func textSecondary() -> some View {
        self
            .foregroundStyle(Color.theme.textSecondary)
    }
    
    func textTertiary() -> some View {
        self
            .foregroundStyle(Color.theme.textTertiary)
    }
}

extension View {
    func hidden(_ shouldHide: Bool) -> some View {
        self
            .opacity(shouldHide ? 0 : 1)
    }
    
    func commentSheetModifiers() -> some View {
        self
            .bottomSheetModifiers()
            .presentationDetents([.fraction(0.75), .fraction(0.999)])
    }
    
    func bottomSheetModifiers() -> some View {
        VStack(spacing: 16) {
            DragBar()
            
            self
        }
        .padding(.top, 14)
        .frameTop()
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .background(Color.theme.surfacesElevatedBlur.blur(radius: 100))
    }


    func onSimultaneousTap(action: @escaping () -> Void) -> some View {
        self
            .simultaneousGesture(TapGesture().onEnded({ action() }))
    }
    
    func onHighPriorityTap(action: @escaping () -> Void) -> some View {
        self
            .highPriorityGesture(TapGesture().onEnded({ action() }))
    }
    
    func overlayAddChangeCover(isImageChosen: Bool, showPicker: @escaping () -> Void, removeCover: @escaping () -> ()) -> some View {
        self
            .overlay(alignment: isImageChosen ? .topTrailing : .center) {
                HStack(spacing: 4) {
                    SmallCTA(
                        type: .tertiary,
                        leadingIcon: "camera",
                        text: isImageChosen ? "Change Cover" : "Add Cover",
                        textColor: .theme.textSecondary,
                        buttonColor: .theme.surfacesPrimary
                    )
                    .onHighPriorityTap {
                        showPicker()
                    }
                    
                    IconImage(name: "x-icon", color: .theme.iconSecondary, size: 12)
                        .padding(5)
                        .background {
                            Circle().fill(Color.theme.surfacesPrimary)
                        }
                        .contentShape(.circle)
                        .onHighPriorityTap {
                            removeCover()
                        }
                        .opacity(isImageChosen ? 1 : 0)
                }
                .padding(12)
            }
    }
}

// MARK: - Backgrounds
extension View {
    // TODO: make sure everything that should have this has this
    func primaryBackground() -> some View {
        self
            .background(Color.theme.surfacesBackgroundPrimary)
    }
    
    func splashBackground() -> some View {
        self
            .background {
                Image("default-gradient")
                    .resizable()
                    .ignoresSafeArea()
                    .scaledToFill()
            }
    }
}

// MARK: - Overlays
extension View {
    func overlayTopRightNotification(when enabled: Bool = true, size: CGFloat = 8) -> some View {
        self
            .overlay(alignment: .topTrailing) {
                if enabled {
                    Circle()
                        .fill(Color.theme.strokeBgMatch)
                        .frame(size + 4)
                        .overlay {
                            Circle()
                                .fill(Color.theme.red)
                                .frame(size)
                        }
                }
            }
    }
    
    func overlayTopLeftNotification(when enabled: Bool = true, size: CGFloat = 8) -> some View {
        self
            .overlay(alignment: .topLeading) {
                if enabled {
                    Circle()
                        .fill(Color.theme.strokeBgMatch)
                        .frame(size + 4)
                        .overlay {
                            Circle()
                                .fill(Color.theme.red)
                                .frame(size)
                        }
                }
            }
    }
    
    func overlayCollectionPreviewStats(likes: Int, comments: Int, hasLiked: Bool, isLivePhoto: Bool, isVideo: Bool, videoDuration: TimeInterval?, videoUrl: URL?, compact: Bool = false) -> some View {
        self
            .overlay(alignment: .bottomLeading) {
                CollectionPreviewStatsView(likes: likes, comments: comments, hasLiked: hasLiked, isLivePhoto: isLivePhoto, isVideo: isVideo, videoDuration: videoDuration, videoUrl: videoUrl, compact: compact)
            }
    }
}

// MARK: - Frame
extension View {
    func width(_ x: CGFloat) -> some View {
        self
            .frame(width: x)
    }
    
    func height(_ y: CGFloat) -> some View {
        self
            .frame(height: y)
    }
    
    /// Sets max height to infinity which has center alignment by default
    func maxHeight(_ alignment: Alignment = .center) -> some View {
        self
            .frame(maxHeight: .infinity, alignment: alignment)
    }
    
    /// Sets max width to infinity which has center alignment by default
    func maxWidth(_ alignment: Alignment = .center) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: alignment)
    }
    
    /// Sets max height to infinity with top alignment
    func frameTop() -> some View {
        self
            .frame(maxHeight: .infinity, alignment: .top)
    }
    
    /// Sets max height to infinity with bottom alignment
    func frameBottom() -> some View {
        self
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
    
    func infiniteFrame() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func frame(_ size: CGFloat) -> some View {
        self
            .frame(width: size, height: size)
    }
    
    func frameRatio(width: CGFloat, ratio: CGFloat) -> some View {
        self
            .frame(width: width, height: width / ratio)
    }
}

extension View {
    func onBecomingVisible(perform action: @escaping () -> Void) -> some View {
        modifier(BecomingVisible(action: action))
    }
}

private struct BecomingVisible: ViewModifier {
    var action: () -> Void
    
    func body(content: Content) -> some View {
        content.overlay {
            InitGeoAfterLoad { proxy in
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: VisibleKey.self,
                            value: UIScreen.main.bounds.intersects(geo.frame(in: .global))
                        )
                }
            }
        }
        .onPreferenceChange(VisibleKey.self) { isVisible in
            DispatchQueue.main.async {
                if isVisible {
                    action()
                }
            }
        }
    }
    
    struct VisibleKey: PreferenceKey {
        static var defaultValue: Bool = false
        static func reduce(value: inout Bool, nextValue: () -> Bool) {
            value = nextValue()
        }
    }
}

struct FadeInFullScreenCoverModifier<V: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let view: () -> V

    @State var isPresentedInternal = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: Binding<Bool>(
                get: { isPresented },
                set: { isPresentedInternal = $0 }
            )) {
                Group {
                    if isPresentedInternal {
                        view()
                            .transition(.opacity)
                            .onDisappear { isPresented = false }
                    }
                }
                .onAppear { isPresentedInternal = true }
                .presentationBackground(.clear)
            }
            .transaction {
                // Disable default fullScreenCover animation
                $0.disablesAnimations = true

                // Add custom animation
                $0.animation = .easeInOut
            }
    }
}

extension View {
    func fadeInFullScreenCover<V: View>(
        isPresented: Binding<Bool>,
        content: @escaping () -> V
    ) -> some View {
        modifier(FadeInFullScreenCoverModifier(
            isPresented: isPresented,
            view: content
        ))
    }
}
