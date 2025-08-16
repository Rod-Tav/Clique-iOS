//
//  FlowBottomButton.swift
//  Clique
//
//  Created by Rod Tavangar on 2/13/25.
//

import SwiftUI

struct FlowBottomButton: View {
    let text: String
    var buttonEnabled: Bool = true
    var buttonLoading: Bool = false
    var canSkip: Bool = false
    let action: () -> Void

    var body: some View {
        CliqueButton(
            type: .primary,
            text: text,
            textColor: buttonEnabled ? .theme.buttonContent : .theme.textTertiary,
            fontWeight: .semibold,
            buttonColor: buttonEnabled ? .theme.buttonCTA : .theme.surfacesElevatedPrimary,
            fullWidth: true,
            isLoading: buttonLoading,
            action: action
        )
        .disabled(!canSkip && (!buttonEnabled || buttonLoading))
        .padding(.bottom, 16)
    }
}
