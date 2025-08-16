////
////  FullSwipeNavigationStack.swift
////  Clique
////
////  Created by Rod Tavangar on 6/15/24.
////
//
//import SwiftUI
//
///// Custom View
//// TODO: ignore if vertical movement is more than horizontal
//struct FullSwipeNavigationStack<Content: View>: View {
//    private var path: Binding<NavigationPath>? // Optional NavigationPath for programmatic navigation
//    private let usesPath: Bool // Flag to determine whether a path is used
//    @ViewBuilder var content: Content
//    
//    /// Full Swipe Custom Gesture
//    @State private var customGesture: UIPanGestureRecognizer = {
//        let gesture = UIPanGestureRecognizer()
//        gesture.name = UUID().uuidString
//        gesture.isEnabled = false
//        return gesture
//    }()
//    
//    /// Constructor for usage with a NavigationPath
//    init(path: Binding<NavigationPath>, @ViewBuilder content: () -> Content) {
//        self.path = path
//        self.usesPath = true
//        self.content = content()
//    }
//    
//    /// Constructor for usage without a NavigationPath
//    init(@ViewBuilder content: () -> Content) {
//        self.usesPath = false
//        self.content = content()
//    }
//    
//    var body: some View {
//        Group {
//            if usesPath, let path = path {
//                NavigationStack(path: path) {
//                    content
//                        .background {
//                            AttachGestureView(gesture: $customGesture)
//                        }
//                }
//            } else {
//                NavigationStack {
//                    content
//                        .background {
//                            AttachGestureView(gesture: $customGesture)
//                        }
//                }
//            }
//        }
//        .environment(\.popGestureID, customGesture.name)
//        .onReceive(NotificationCenter.default.publisher(for: .init(customGesture.name ?? ""))) { info in
//            if let userInfo = info.userInfo, let status = userInfo["status"] as? Bool {
//                customGesture.isEnabled = status
//            }
//        }
//    }
//}
//
///// Custom Environment Key for Passing Gesture ID to its subviews
//fileprivate struct PopNotificationID: EnvironmentKey {
//    static var defaultValue: String?
//}
//
//fileprivate extension EnvironmentValues {
//    var popGestureID: String? {
//        get {
//            self[PopNotificationID.self]
//        }
//        
//        set {
//            self[PopNotificationID.self] = newValue
//        }
//    }
//}
//
//extension View {
//    @ViewBuilder
//    func enableFullSwipePop(_ isEnabled: Bool) -> some View {
//        self
//            .modifier(FullSwipeModifier(isEnabled: isEnabled))
//    }
//}
//
///// Helper View Modifier
//fileprivate struct FullSwipeModifier: ViewModifier {
//    var isEnabled: Bool
//    /// Gesture ID
//    @Environment(\.popGestureID) private var gestureID
//    func body(content: Content) -> some View {
//        content
//            .onChange(of: isEnabled, initial: true) { oldValue, newValue in
//                guard let gestureID = gestureID else { return }
//                NotificationCenter.default.post(name: .init(gestureID), object: nil, userInfo: [
//                    "status": newValue
//                ])
//            }
//    }
//}
//
///// Helper Files
//fileprivate struct AttachGestureView: UIViewRepresentable {
//    @Binding var gesture: UIPanGestureRecognizer
//    func makeUIView(context: Context) -> UIView {
//        return UIView()
//    }
//    
//    func updateUIView(_ uiView: UIView, context: Context) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
//            /// Finding Parent Controller
//            if let parentViewController = uiView.parentViewController {
//                if let navigationController = parentViewController.navigationController {
//                    /// Checking if already the gesture has been added to the controller
//                    if let _ = navigationController.view.gestureRecognizers?.first(where: {
//                        $0.name == gesture.name }) {
//                    } else {
//                        navigationController.addFullSwipeGesture(gesture)
//                    }
//                }
//            }
//        }
//    }
//}
//
//fileprivate extension UINavigationController {
//    /// Adding Custom FullSwipe Gesture
//    func addFullSwipeGesture(_ gesture: UIPanGestureRecognizer) {
//        guard let gestureSelector = interactivePopGestureRecognizer?.value(forKey: "targets") else { return }
//        
//        gesture.setValue(gestureSelector, forKey: "targets")
//        view.addGestureRecognizer(gesture)
//    }
//}
//
//fileprivate extension UIView {
//    var parentViewController: UIViewController? {
//        sequence(first: self) {
//            $0.next
//        }.first(where: {$0 is UIViewController}) as? UIViewController
//    }
//}
//
//#Preview {
//    ContentView()
//}
