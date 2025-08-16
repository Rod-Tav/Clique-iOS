//
//  TopIconFlowCoordinator.swift
//  Clique
//
//  Created by Rod Tavangar on 1/17/25.
//

import SwiftUI

@Observable
class TopIconFlowCoordinator {
    var currentIconStep: Int = 1
    var highlightNextBar: Bool = false
    var iconBgColor: Color = .theme.lightPink
    var path: NavigationPath = NavigationPath()
    var backButtonAction: () -> Void = { }
    var isRootOfStep: Bool = true
    var bottomButton: () -> AnyView = {
        AnyView(EmptyView())
    }
    
    func reset() {
        currentIconStep = 1
        highlightNextBar = false
        iconBgColor = .theme.lightPink
        path = NavigationPath()
        backButtonAction = { }
        isRootOfStep = true
        bottomButton = { AnyView(EmptyView()) }
    }
}
