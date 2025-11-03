//
//  ReportFeedItemView.swift
//  Clique
//
//  Created by Quinn Liu on 3/3/25.
//

import Toasts
import SwiftUI

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserStore.self) private var userStore

    @Binding var showReport: Bool
    
    let objectId: String
    let reportType: ReportType
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TopBar()
                
                ReportBlurb()
                
                ReportOptions()
            }
            .frameTop()
            .padding(.horizontal, 16)
            .primaryBackground()
        }
    }
    
    // MARK: TopBar
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage(name: "x-icon", color: .theme.iconPrimary, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: {
                Text("Report \(reportType.capitalized)")
                    .font(.callout.weight(.semibold))
            },
            trailingIcon: { Spacer().frame(24) }
        )
    }
    
    // MARK: ReportBlurb
    @ViewBuilder private func ReportBlurb() -> some View {
        VStack(alignment: .center, spacing: 12) {
            Group {
                Text("Let us know why you’re reporting this")
                    .fontWeight(.semibold)
                
                Text("Your report helps keep the Clique community safe. The poster will not be notified when you submit this report. If someone is in immediate danger, please contact local emergency services right away.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.theme.textSecondary)
            }.font(.footnote)
        }
        .padding(24)
        .background(Color.theme.surfacesElevatedPrimary)
        .roundCorners(16)
    }
    
    // MARK: ReportOptions
    @ViewBuilder private func ReportOptions() -> some View {
        if let currentUserId = userStore.currentUserId {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(reportType.reportReasons, id: \.self) { reason in
                        NavigationLink(destination: ReportEntryView(showReport: $showReport, reporterId: currentUserId, objectId: objectId, reportType: reportType, reportReason: reason, date: Date())) {
                            HStack(spacing: 0) {
                                Text(reason)
                                    .font(.callout)
                                
                                Spacer()
                                
                                IconImage(name: "chevron-right", color: .theme.iconPrimary, size: 20)
                            }
                            .contentShape(.rect)
                            .padding(.vertical, 12)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - ReportEntryView
struct ReportEntryView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast

    @Binding var showReport: Bool
    
    @State private var viewModel: ReportViewModel
    
    init(showReport: Binding<Bool>, reporterId: String, objectId: String, reportType: ReportType, reportReason: String, date: Date) {
        self._showReport = showReport
        self._viewModel = State(initialValue: ReportViewModel(reporterId: reporterId, objectId: objectId, reportType: reportType, reportReason: reportReason, date: date))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            TopBar()
            
            ReportReason()
            
            ReportDetailsEntry()
            
            CliqueButton(type: .primary, text: "Submit", fullWidth: true) {
                viewModel.sendReport() { result in
                    switch result {
                    case .success:
                        presentToast(Toasts.reportSuccess)
                    case .conflict:
                        presentToast(Toasts.reportExists)
                    case .failure:
                        presentToast(Toasts.reportFailure)
                    }
                }
                showReport = false
            }
        }
        .navigationBarBackButtonHidden()
        .frameTop()
        .padding(.horizontal, 16)
        .primaryBackground()
    }
    
    // MARK: TopBar
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                BackButton(size: 24)
            },
            header: {
                Text("Report \(viewModel.report.reportType.capitalized)")
                    .font(.callout.weight(.semibold))
            },
            trailingIcon: { Spacer().frame(24) }
        )
    }
    
    // MARK: ReportReason
    @ViewBuilder private func ReportReason() -> some View {
        Text(viewModel.report.reportReason)
            .frame(maxWidth: .infinity)
            .font(.footnote.weight(.semibold))
            .padding(24)
            .background(Color.theme.surfacesElevatedPrimary)
            .cornerRadius(16)
    }
    
    // MARK: ReportDetailsEntry
    @ViewBuilder private func ReportDetailsEntry() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text("Add a comment to your report (optional)")
                
                Spacer()
                
                Text("\(viewModel.report.reportDescription.count)/200")
            }
            
            TextField("Enter report here", text: $viewModel.report.reportDescription, axis: .vertical)
                .onChange(of: viewModel.report.reportDescription) {
                    if viewModel.report.reportDescription.count > 200 {
                    viewModel.report.reportDescription = String(viewModel.report.reportDescription.prefix(200))
                    }
                }
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.theme.strokeSecondary, lineWidth: 1)
                )
        }
        .font(.footnote)
    }
}

#Preview {
    ReportView(showReport: .constant(true), objectId: "testCollection", reportType: .collection)
}
