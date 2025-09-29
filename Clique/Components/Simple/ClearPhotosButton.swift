//
//  ClearPhotosButton.swift
//  Clique
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI

struct ClearPhotosButton: View {
    let count: Int
    let action: () -> Void

    init(count: Int, action: @escaping () -> Void) {
        self.count = count
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text("Clear (\(count))")
                .font(.caption.bold())
                .foregroundStyle(Color.theme.red)
        }
    }
}