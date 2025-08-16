//
//  ProfileTabSwitcherCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 12/6/24.
//

import Observation

@Observable final class ProfileTabSwitcherCoordinator {
    var isScrolling: Bool = false
    var smallHeader: Bool = false
    var smallHeaderAnimationComplete: Bool = false
    
    var scrollToTop: Bool = false
    var canGoUp = [Int: Bool]() // tab id to bool
    
    var selectedTab: Int? = 0
}
