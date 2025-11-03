//
//  MainZoomTransition.swift
//  Clique
//
//  Created by Rod Tavangar on 12/10/24.
//

import SwiftUI
import SwiftUINavigationTransitions

extension AnyNavigationTransition {
    static func mainZoom(xOffset: CGFloat = 0, yOffset: CGFloat = 0, scaleFactor: CGFloat = 1.0) -> Self {
        .init(ZoomTransition(xOffset: xOffset, yOffset: yOffset, scaleFactor: scaleFactor))
    }
}

struct ZoomTransition: NavigationTransitionProtocol {
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var scaleFactor: CGFloat = 1.0
    
    var body: some NavigationTransitionProtocol {
        OnPush {
            OnInsertion { // right view arrives
                Offset(x: xOffset, y: yOffset)
                Scale(scaleFactor)
            }
            OnRemoval { // left view arrives
//                Scale(Constants.transitionShrinkFactor)
//                Offset(x: xOffset)
            }
        }
        OnPop {
            OnInsertion { // left view leaves
                
//                Scale(Constants.transitionShrinkFactor)
            }
            OnRemoval { // right view leaves
                Offset(x: xOffset, y: yOffset)
                Scale(scaleFactor)
                Opacity()
            }
        }
    }
}

