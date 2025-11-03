//
//  TopIconFlow.swift
//  Clique
//
//  Created by Rod Tavangar on 1/10/25.
//

import SwiftUI

// parameters to control 1) through what step is highlighted and 2) whether the proceeding bar should be highlighted or not
// color param that defaults to skyblue (green at end of clique creator)
struct TopIconFlow: View {
    @Environment(\.dismiss) private var dismiss
    var buttonEnabled: Bool = true
    let steps: [FlowStep]
    
    var dismissFromStart: (() -> Void)? = nil
   
    @State private var currentStep: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(
                type: .small,
                leadingIcon: {
                    Button {
                        if currentStep == 0 {
                            dismissFromStart?() ?? dismiss()
                        } else {
                            currentStep -= 1
                        }
                    } label: {
                        IconImage(name: "arrow-left", color: .theme.iconSecondary, size: 24)
                    }
                },
                header: TopIcons,
                trailingIcon: {
                    Rectangle().fill(.clear).frame(24)
                }
            )
            
            steps[currentStep].view
                .animation(.easeInOut, value: currentStep)

            Spacer()
            
            CliqueButton(
                type: .primary,
                text: steps[currentStep].buttonTitle,
                textColor: steps[currentStep].buttonTextColor,
                buttonColor: steps[currentStep].buttonColor,
                fullWidth: true
            ) {
                if !steps[currentStep].isButtonDisabled, currentStep < steps.count - 1 {
                    currentStep += 1
                }
            }.buttonStyle(.noHighlight)
        }
    }
    
    @ViewBuilder
    private func TopIcons() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(spacing: 8) {
                    IconImage(name: steps[index].imageName, color: .theme.shadesWhite95, size: 12)
                }
                .frame(24)
                .background(index > currentStep ? Color.theme.surfacesElevatedPrimary : Color.theme.lightPink)
                .clipShape(.circle)
                
                if index < steps.count - 1 {
                    Rectangle()
                      .foregroundColor(.clear)
                      .frame(width: 32, height: 4)
                      .background(index >= currentStep ? Color.theme.surfacesElevatedPrimary : Color.theme.lightPink)
                      .roundCorners(8)
                }
            }
        }
    }
}

// Represents a step in the flow
struct FlowStep {
    let imageName: String
    let buttonTitle: String
    var buttonColor: Color?
    var buttonTextColor: Color?
    var isButtonDisabled: Bool = false
    let view: AnyView
}
