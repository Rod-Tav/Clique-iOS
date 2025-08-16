////
////  File.swift
////  Clique
////
////  Created by Rod Tavangar on 12/8/24.
////
//
//import SwiftUI
//import NavigationTransition
//
//extension AnyNavigationTransition {
//    static var swing: Self {
//        .init(Swing())
//    }
//}
//
//struct Swing: NavigationTransitionProtocol {
//    var body: some NavigationTransitionProtocol {
//        Slide(axis: .horizontal)
//        MirrorPush {
//            OnInsertion {
//                Move(edge: .trailing)
//            }
//            OnRemoval {
//                Move(edge: .leading)
//            }
//        }
//    }
//}
//
//extension AnyNavigationTransition {
//    /// A transition that moves both views in and out along the specified axis.
//    ///
//    /// This transition:
//    /// - Pushes views right-to-left and pops views left-to-right when `axis` is `horizontal`.
//    /// - Pushes views bottom-to-top and pops views top-to-bottom when `axis` is `vertical`.
//    public static func slide2(axis: Axis) -> Self {
//        .init(Slide2(axis: axis))
//    }
//}
//
//extension AnyNavigationTransition {
//    /// Equivalent to `slide(axis: .horizontal)`.
//    @inlinable
//    public static var mainTransition: Self {
//        .slide2(axis: .horizontal)
//    }
//}
//
///// A transition that moves both views in and out along the specified axis.
/////
///// This transition:
///// - Pushes views right-to-left and pops views left-to-right when `axis` is `horizontal`.
///// - Pushes views bottom-to-top and pops views top-to-bottom when `axis` is `vertical`.
//public struct Slide2: NavigationTransitionProtocol {
//    private let axis: Axis
//
//    public init(axis: Axis) {
//        self.axis = axis
//    }
//
//    /// Equivalent to `Move(axis: .horizontal)`.
//    @inlinable
//    public init() {
//        self.init(axis: .horizontal)
//    }
//
//    public var body: some NavigationTransitionProtocol {
//        switch axis {
//        case .horizontal:
//            MirrorPush {
//                OnInsertion {
//                    Move2(edge: .trailing)
//                }
//                OnRemoval {
//                    Move2(edge: .leading)
//                }
//            }
//        case .vertical:
//            MirrorPush {
//                OnInsertion {
//                    Move(edge: .bottom)
//                }
//                OnRemoval {
//                    Move(edge: .top)
//                }
//            }
//        }
//    }
//}
//

import SwiftUI
import NavigationTransition

//extension Slide2: Hashable {}

/// A transition entering from `edge` on insertion, and exiting towards `edge` on removal.
public struct Move2: MirrorableAtomicTransition {
    private let edge: Edge
    
    // TODO: changing scale factor messes with ProfileTabSwitcher header pan to dismiss. It shouldn't do this, but scaleFactor isn't needed right now since I think animation looks better without it. Probably a problem in ProfileTabSwitcher and clique banner aspect ratio
    // TODO: changing shrink factor makes cornerRadius of clique banner obvious on dark mode. I can't figure out how to remove the background behind left view
    private var scaleFactor: CGFloat = 1
    private var shrinkFactor: CGFloat = 1
    private var dismissDistance: CGFloat = 150
    private var dismissAlpha: CGFloat = 1

    public init(edge: Edge) {
        self.edge = edge
    }

    public func transition(_ view: TransientView, for operation: TransitionOperation, in container: Container) {
        switch (edge, operation) {
        case (.leading, .insertion): // left view arrives
            view.initial.transform.translate(x: -dismissDistance)
//            view.initial.transform.scale(x: shrinkFactor, y: shrinkFactor, z: 1)
            view.initial.alpha = dismissAlpha
            view.animation.alpha = 1
            view.animation.transform = .identity

        case (.trailing, .insertion): // right view arrives
            let translation = (container.frame.width * scaleFactor - container.frame.width) / 2
            view.initial.transform.translate(x: container.frame.width + translation + container.frame.width / 4)
//            view.initial.transform.scale(x: scaleFactor, y: scaleFactor, z: 1)
            view.animation.transform = .identity

        case (.leading, .removal): // left view leaves
            view.animation.transform.translate(x: -dismissDistance)
//            view.animation.transform.scale(x: shrinkFactor, y: shrinkFactor, z: 1)
            view.animation.alpha = dismissAlpha
            view.completion.transform = .identity

        case (.trailing, .removal): // right view leaves
            let translation = (container.frame.width * scaleFactor - container.frame.width) / 2
            view.animation.transform.translate(x: container.frame.width + translation)
//            view.animation.transform.scale(x: scaleFactor, y: scaleFactor, z: 1)
            view.completion.transform = .identity

        default:
            view.completion.transform = .identity
        }
    }

    public func mirrored() -> Move2 {
        switch edge {
        case .top:
            return .init(edge: .bottom)
        case .leading:
            return .init(edge: .trailing)
        case .bottom:
            return .init(edge: .top)
        case .trailing:
            return .init(edge: .leading)
        }
    }
}

extension Move2: Hashable {}
