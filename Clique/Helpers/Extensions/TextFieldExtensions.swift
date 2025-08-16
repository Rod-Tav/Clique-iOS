//
//  TextFieldExtensions.swift
//  Clique
//
//  Created by Rod Tavangar on 2/13/25.
//

import SwiftUI

extension View {
    func limitTextField(to length: Int, text: Binding<String>) -> some View {
        self
            .onChange(of: text.wrappedValue) { _, newValue in
                if newValue.count > length {
                    text.wrappedValue = String(newValue.prefix(length))
                }
            }
    }
    
    // workaround because onSubmit doesn't work for vertical textfield
    func onEnter(@Binding of text: String, action: @escaping () -> ()) -> some View {
        onChange(of: text) { _, newValue in
            if let last = newValue.last, last == "\n" {
                text.removeLast()
                action()
            }
        }
    }
}
