//
//  GlobalSafeAreaInsets.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

struct SafeAreaInsetPaddingModifier: ViewModifier {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    let alignments: Edge.Set
    
    func body(content: Content) -> some View {
        content
            .padding(alignments, alignments.contains(.top) ? safeAreaInsets.top : safeAreaInsets.bottom)
    }
}

extension View {
    func padSafeArea(_ alignments: Edge.Set) -> some View {
        modifier(SafeAreaInsetPaddingModifier(alignments: alignments))
    }
}

extension UIApplication {
    var keyWindow: UIWindow? {
        guard Thread.isMainThread else { return nil } // Ensure main thread
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        UIApplication.shared.keyWindow?.safeAreaInsets.swiftUiInsets ?? EdgeInsets()
    }
}


private extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}
