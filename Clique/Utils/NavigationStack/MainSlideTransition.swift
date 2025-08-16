//
//  ZoomTransition.swift
//  Clique
//
//  Created by Rod Tavangar on 12/8/24.
//

import SwiftUINavigationTransitions

extension AnyNavigationTransition {
    static var mainSlide: Self {
        .init(MainTransition())
    }
}

struct MainTransition: NavigationTransitionProtocol {
    // TODO: changing scale factor messes with ProfileTabSwitcher header pan to dismiss. It shouldn't do this, but scaleFactor isn't needed right now since I think animation looks better without it. Probably a problem in ProfileTabSwitcher and clique banner aspect ratio
    // TODO: changing shrink factor makes cornerRadius of clique banner obvious on dark mode. I can't figure out how to remove the background behind left view
    // not sure if this second todo is still true
    var body: some NavigationTransitionProtocol {
        OnPush {
            OnInsertion { // right view arrives
                Move(edge: .trailing)
            }
            OnRemoval { // left view arrives
//                Scale(Constants.transitionShrinkFactor)
                Offset(x: -50)
            }
        }
        OnPop {
            OnInsertion { // left view leaves
                Offset(x: -50)
//                Scale(Constants.transitionShrinkFactor)
            }
            OnRemoval { // right view leaves
                Move(edge: .trailing)
            }
        }
    }
}
