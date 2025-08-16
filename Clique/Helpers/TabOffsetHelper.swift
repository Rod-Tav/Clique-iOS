//
//  TabOffsetHelper.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

/// Offset Key and offsetX for tab switching
struct XOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct YOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    @ViewBuilder
    func offsetX(completion: @escaping (CGFloat) -> ()) -> some View {
        self
            .overlay {
                InitGeoAfterLoad { proxy in
                    GeometryReader {
                        let minX = $0.frame(in: .scrollView(axis: .horizontal)).minX
                        
                        Color.clear
                            .preference(key: XOffsetKey.self, value: minX)
                            .onPreferenceChange(XOffsetKey.self, perform: completion)
                    }
                }
            }
    }
    
    @ViewBuilder
        func offsetY(completion: @escaping (CGFloat) -> ()) -> some View {
            self
                .overlay {
                    InitGeoAfterLoad { proxy in // TODO: test without
                        GeometryReader {
                            let minY = $0.frame(in: .scrollView(axis: .vertical)).minY
                            
                            Color.clear
                                .preference(key: YOffsetKey.self, value: minY)
                                .onPreferenceChange(YOffsetKey.self, perform: completion)
                        }
                    }
                }
        }
}
