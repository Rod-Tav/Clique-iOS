//
//  ReportButton.swift
//  Clique
//
//  Created by Rod Tavangar on 2/10/25.
//

import SwiftUI

struct ReportButton: View {
    var action: () -> Void = { }
    
    var body: some View {
        Button(role: .destructive) {
            action()
        } label: {
            Text("Report")
            
            Image("flag")
                .color(.theme.red)
        }
    }
}

#Preview {
    ReportButton()
}
