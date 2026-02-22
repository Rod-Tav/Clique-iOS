//
//  CreateCliqueView.swift
//  CliqueMessages
//
//  View for creating a new clique in the iMessage extension
//

import SwiftUI


struct CreateCliqueView: View {
    @Environment(ExtensionViewModel.self) var viewModel

    // MARK: - State

    @State var cliqueName: String = ""
    @State var linkToChat: Bool = true
    @State var isCreating: Bool = false
    @State var showAlert: Bool = false
    @FocusState var isTextFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.extensionBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                formContent
                Spacer()
                actionButtons
            }
            .disabled(isCreating)

            if isCreating {
                loadingOverlay
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .alert("Coming Soon", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                viewModel.navigateBack()
            }
        } message: {
            Text("API integration pending. This feature will create a new clique and optionally link it to this iMessage conversation.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Text("Create New Clique")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.extensionPrimaryText)

            Text("Share photos with your friends")
                .font(.subheadline)
                .foregroundStyle(Color.extensionSecondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.extensionSecondaryBackground)
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            cliqueNameField

            linkToChatSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var cliqueNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clique Name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.extensionPrimaryText)

            TextField("Enter clique name", text: $cliqueName)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            HStack(spacing: 4) {
                Image(systemName: validationIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(validationColor)

                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationColor)
            }
            .opacity(cliqueName.isEmpty ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: cliqueName.isEmpty)
        }
    }

    private var linkToChatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $linkToChat) {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(linkToChat ? Color.cliquePink : Color.extensionSecondaryText)

                    Text("Link to this chat")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.extensionPrimaryText)
                }
            }
            .tint(Color.cliquePink)

            if linkToChat {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.extensionSecondaryText)
                        .padding(.top, 2)

                    Text("Members of this clique will be able to send photos directly to this iMessage conversation. Perfect for group chats!")
                        .font(.caption)
                        .foregroundStyle(Color.extensionSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.extensionSecondaryBackground)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: linkToChat)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            createButton
            cancelButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var createButton: some View {
        Button {
            createClique()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("Create Clique")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFormValid ? Color.cliquePink : Color.extensionSecondaryText.opacity(0.5))
            )
        }
        .disabled(!isFormValid)
    }

    private var cancelButton: some View {
        Button {
            viewModel.navigateBack()
        } label: {
            Text("Cancel")
                .font(.body)
                .foregroundStyle(Color.extensionSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)

                Text("Creating clique...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.extensionPrimaryText.opacity(0.95))
            )
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !cliqueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        cliqueName.count >= 2 &&
        cliqueName.count <= 50
    }

    private var validationIcon: String {
        if cliqueName.count < 2 {
            return "exclamationmark.circle.fill"
        } else if cliqueName.count > 50 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var validationColor: Color {
        if cliqueName.count < 2 {
            return Color.orange
        } else if cliqueName.count > 50 {
            return Color.red
        } else {
            return Color.green
        }
    }

    private var validationMessage: String {
        if cliqueName.count < 2 {
            return "Name must be at least 2 characters"
        } else if cliqueName.count > 50 {
            return "Name must be 50 characters or less"
        } else {
            return "Looks good!"
        }
    }

    // MARK: - Actions

    private func createClique() {
        isTextFieldFocused = false
        isCreating = true

        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCreating = false
            showAlert = true

            // Future implementation:
            // 1. Call API to create clique with name
            // 2. If linkToChat is true, associate chatKey with clique
            // 3. Send clique invite message to conversation
            // 4. Navigate back to clique list
            // 5. Refresh clique cache
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CreateCliqueView_Previews: PreviewProvider {
    static var previews: some View {
        CreateCliqueView()
            .environment(mockViewModel())

        CreateCliqueView()
            .environment(mockViewModel())
            .preferredColorScheme(.dark)
    }

    static func mockViewModel() -> ExtensionViewModel {
        let viewModel = ExtensionViewModel()
        viewModel.chatKey = "mock-chat-key-12345"
        return viewModel
    }
}
#endif
