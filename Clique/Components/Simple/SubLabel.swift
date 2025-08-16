//
//  SubLabel.swift
//  Clique
//
//  Created by Rod Tavangar on 1/9/25.
//

import SwiftUI

struct SubLabel<LeadingIcon: View, Text: View>: View {
    @ViewBuilder var text: Text
    @ViewBuilder var leadingIcon: LeadingIcon
    
    var body: some View {
        HStack(spacing: 4) {
            leadingIcon
            
            text
        }
    }
}
