//
//  EnterBirthdayScreen.swift
//  Clique
//
//  Created by Quinn Liu on 1/23/25.
//

import SwiftUI

private enum FocusedField {
    case month, day, year
}

private extension String {
    var isValidMonth: Bool {
        self.count == 2
    }
    var isValidDay: Bool {
        self.count == 2
    }
    var isValidYear: Bool {
        self.count == 4
    }
}

struct EnterBirthdayScreen: View {
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(AuthFlowViewModel.self) private var viewModel
    
    @FocusState private var focusedField: FocusedField?
    
    @State private var month: String = ""
    @State private var day: String = ""
    @State private var year: String = ""
    
    @State private var isUnderAge: Bool = false
    
    private var buttonEnabled: Bool {
        !isUnderAge && formatDateMMddyyyy(viewModel.birthday) != formatDateMMddyyyy(Date())
    }
    
    var body: some View {
//        AuthContentView(
//            title: "When's your birthday?",
//            inputView: {
//                BirthdayEntry()
//            }
//        )
        
        
        VStack(alignment: .leading, spacing: 48) {
            Text("When's your birthday?")
                .textPrimary()
                .font(.largeTitle.bold())
                .kerning(0.1292)
            
            BirthdayPicker()
        }
        .maxWidth(.leading)
        .onAppear {
            focusedField = .month
            
            coordinator.backButtonAction = {
                coordinator.highlightNextBar = true
            }
            coordinator.isRootOfStep = true
        }
        .onChange(of: buttonEnabled, initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
        .disabled(isUnderAge)
    }
    
    @ViewBuilder
    private func BirthdayPicker() -> some View {
        @Bindable var bindableVm = viewModel
        
//        DatePicker(
//            "birthday",
//            selection: $bindableVm.birthday,
//            in: ...Date(),
//            displayedComponents: [.date]
//        )
//        .labelsHidden()
//        .datePickerStyle(.wheel)
//        .frame(maxWidth: .infinity)
//        //                    .padding(.top, 48)
//        .id(UUID()) // sizing issue
        // TODO: figure out why the top text jumps
        
        HStack(spacing: 8) {
            TextField("MM", text: $month)
                .focused($focusedField, equals: .month)
                .keyboardType(.numberPad)
                .onChange(of: month) {
                    if month.count == 2 {
                        focusedField = .day
                    }
                }
                .limitTextField(to: 2, text: $month)
            
            TextField("DD", text: $day)
                .focused($focusedField, equals: .day)
                .keyboardType(.numberPad)
                .onChange(of: day) {
                    if day.count == 2 {
                        focusedField = .year
                    }
                }
                .limitTextField(to: 2, text: $day)
            
            TextField("YYYY", text: $year)
                .focused($focusedField, equals: .year)
                .keyboardType(.numberPad)
                .limitTextField(to: 4, text: $year)
                .onChange(of: year) {
                    if year.count == 4 {
                        guard let monthInt = Int(month),
                              let dayInt = Int(day),
                              let yearInt = Int(year) else {
                            return
                        }
                        
                        var components = DateComponents()
                        components.year = yearInt
                        components.month = monthInt
                        components.day = dayInt
                        
                        viewModel.birthday = Calendar.current.date(from: components) ?? Date()
                    }
                }
        }
        .textPrimary()
        .font(.largeTitle.bold())
        .kerning(0.1292)
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Bottom Button
extension EnterBirthdayScreen {
    @ViewBuilder private func BottomButton() -> some View {
        VStack(spacing: 16) {
            Text("You must be 16 or older to use Clique. We do not store your birthday.")
                .foregroundStyle(isUnderAge ? Color.theme.red : Color.theme.textSecondary)
                .multilineTextAlignment(.center)
                .font(.footnote)
            
            FlowBottomButton(
                text: "Next",
                buttonEnabled: buttonEnabled
            ) { bottomButtonAction() }
        }
    }
    
    private func bottomButtonAction() {
        guard Int(month) != nil, Int(day) != nil, Int(year) != nil else { return }
        
        if let sixteenYearsAgo = Calendar.current.date(byAdding: .year, value: -16, to: Date()) {
            if viewModel.birthday <= sixteenYearsAgo {
                coordinator.path.append(2.1)
            } else {
                isUnderAge = true
            }
        }
    }
}

#Preview {
    EnterBirthdayScreen()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
        .frameTop()
}
