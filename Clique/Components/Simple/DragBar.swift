//
//  DragBar.swift
//  Clique
//
//  Created by Rod Tavangar on 1/9/25.
//

import SwiftUI

struct DragBar: View {
    var color: Color = .theme.textSecondary
    
    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 32, height: 4)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    DragBar()
}
