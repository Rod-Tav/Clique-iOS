//
//  View+Extensions.swift
//  Clique
//
//  Created by Rod Tavangar on 6/14/24.
//

import SwiftUI
import BezelKit

/// Custom View Modifiers
extension View {
    @ViewBuilder
    func hideNativeTabBar() -> some View {
        self
            .toolbar(.hidden, for: .tabBar)
    }
}

// Bottom sheet over tab bar
extension View {
    @ViewBuilder
    func didFrameChange(result: @escaping (CGRect, CGRect) -> ()) -> some View {
        self
            .overlay {
                InitGeoAfterLoad { geometry in
                    GeometryReader {
                        let frame = $0.frame(in: .scrollView(axis: .vertical))
                        let bounds = $0.bounds(of: .scrollView(axis: .vertical)) ?? .zero
                        
                        Color.clear
                            .preference(key: FrameKey.self, value: .init(frame: frame, bounds: bounds))
                            .onPreferenceChange(FrameKey.self, perform: { value in
                                result(value.frame, value.bounds)
                            })
                    }
                }
            }
    }
}

struct ViewFrame: Equatable {
    var frame: CGRect = .zero
    var bounds: CGRect = .zero
}

struct FrameKey: PreferenceKey {
    static var defaultValue: ViewFrame = .init()
    static func reduce(value: inout ViewFrame, nextValue: () -> ViewFrame) {
        value = nextValue()
    }
}


// TODO: containerRelativeFrame and aspectRatio refactor (assuming it works)
extension UIWindow {
    static var current: UIWindow? {
        return MainActor.assumeIsolated {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    if window.isKeyWindow { return window }
                }
            }
            return nil
        }
    }
}
extension UIScreen {
    static var current: UIScreen? {
//        MainActor.assumeIsolated {
            UIWindow.current?.screen
//        }
    }

    static var width: CGFloat {
//        MainActor.assumeIsolated {
            UIScreen.current?.bounds.width ?? 0
//        }
    }

    static var height: CGFloat {
//        MainActor.assumeIsolated {
            UIScreen.current?.bounds.height ?? 0
//        }
    }
}

/// view size

struct ViewPreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

extension View {
    func getSize(size: @escaping (CGSize) -> Void) -> some View {
        background(
            InitGeoAfterLoad { proxy in
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ViewPreferenceKey.self, value: geo.size)
                }
            }
        )
        .onPreferenceChange(ViewPreferenceKey.self, perform: size)
    }
}

struct SizeReader: ViewModifier {
    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .background (
                InitGeoAfterLoad { proxy in
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.size, initial: true) { oldVal, newVal in
                                size = newVal
                            }
                    }
                }
            )
    }
}

extension View {
    func sizeReader(size: Binding<CGSize>) -> some View {
        modifier(SizeReader(size: size))
    }
}

extension View {
    // https://www.avanderlee.com/swiftui/conditional-view-modifier/
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

extension Bool {
    static var iOS26: Bool {
        guard #available(iOS 26, *) else {
            return false
        }
        
        return true
    }
    
    static var iOS18: Bool {
        guard #available(iOS 18, *) else {
            return false
        }
        
        return true
    }
}

/// initialize view after load -- https://stackoverflow.com/questions/72704975/
struct InitGeoAfterLoad<Content: View>: View {

    @ViewBuilder let content: (CGSize) -> Content

    private struct AreaReader: Shape {
        @Binding var size: CGSize

        func path(in rect: CGRect) -> Path {
            DispatchQueue.main.async {
                size = rect.size
            }
            return Rectangle().path(in: rect)
        }
    }

    @State private var size = CGSize.zero

    var body: some View {
        // by default shape is black so we need to clear it explicitly
        AreaReader(size: $size).foregroundColor(.clear)
            .overlay(Group {
                if size != .zero {
                    content(size)
                }
            })
    }
}

extension UITabBarController {
    var height: CGFloat {
        return self.tabBar.frame.size.height
    }
    
    var width: CGFloat {
        return self.tabBar.frame.size.width
    }
}


extension View {
    func clipTopCorners() -> some View {
        let cornerRadius = CGFloat.deviceBezel
        return self
            .mask(
                UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: cornerRadius,
                    topTrailing: cornerRadius
                ),
                style: .continuous
            ))
    }
}

extension View {
    @ViewBuilder
    func viewExtractor(result: @escaping (UIView) -> ()) -> some View {
        self
            .background(ViewExtractHelper(result: result))
            .compositingGroup()
    }
}

fileprivate struct ViewExtractHelper: UIViewRepresentable {
    var result: (UIView) -> ()
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            if let uiKitView = view.superview?.superview?.subviews.last?.subviews.first {
                result(uiKitView)
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Glass Button Modifier
struct GlassButtonModifier: ViewModifier {
    let backgroundColor: Color

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(backgroundColor)
                .clipShape(.capsule)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(backgroundColor)
                .clipShape(.capsule)
        }
    }
}

extension View {
    func glassButton(backgroundColor: Color) -> some View {
        modifier(GlassButtonModifier(backgroundColor: backgroundColor))
    }
}

