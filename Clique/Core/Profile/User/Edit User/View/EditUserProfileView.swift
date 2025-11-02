//
//  EditUserProfileView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/27/24.
//

import SwiftUI
import PhotosUI
import Toasts

private enum FocusedField {
    case first, last, username, bio
    
    var autoCapitalization: TextInputAutocapitalization {
        switch self {
        case .first, .last: .words
        case .username: .never
        case .bio: .sentences
        }
    }
}

struct EditUserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
//    @Environment(EditUserProfileCoordinator.self) private var editUserProfileCoordinator
    @Environment(UserStore.self) private var userStore
    
    @State var viewModel: EditUserProfileViewModel
    
    @State private var showPicker: Bool = false
    @FocusState private var focusedField: FocusedField?
    @State private var savingLoading: Bool = false
    
    @State private var isUsernameTaken: Bool = true
    @State private var hasTriedUsername: Bool = false
    
    private var initialUsername: String
    
    let uid: String
    
    private var user: User? {
        userStore.users[uid]
    }
    
    init(user: User) {
        self.uid = user.id
        self.viewModel = .init(user: user)
        initialUsername = user.username
    }
    
    private var canSave: Bool {
        !(viewModel.firstname.isEmpty || viewModel.lastname.isEmpty || viewModel.username.isEmpty)
    }
    
    var body: some View {
        @Bindable var bindableVm = viewModel
        
        VStack(spacing: 24) {
            TopBar()
            
            //            PhotosPicker(selection: $viewModel.selectedImage) {
            Button {
                showPicker.toggle()
            } label: {
                VStack {
                    if let pfp = viewModel.pfp {
                        Image(uiImage: pfp)
                            .userPfp(size: 72)
                    } else {
                        UserPfpAsyncView(pfp: user?.profilePic, size: 72, quality: .low)
                    }
                    
                    SmallCTA(type: .secondary, text: "Edit") {
                        showPicker.toggle()
                    }
                }
            }
            
            VStack(spacing: 12) {
                EditRow(title: "First Name", text: $bindableVm.firstname, focusField: .first)
                
                EditRow(title: "Last Name", text: $bindableVm.lastname, focusField: .last)
                
                EditRow(title: "Username", text: $bindableVm.username, focusField: .username)
                
                EditRow(title: "Bio", text: $bindableVm.bio, focusField: .bio)
            }
        }
        .frameTop()
        .padding(.horizontal, 16)
        .cropImagePicker(
            type: .circle,
            show: $showPicker,
            croppedUIImage: $bindableVm.pfp
        )
        .primaryBackground()
    }
}

// MARK: - Top Bar
extension EditUserProfileView {
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage("x-icon", color: .theme.iconPrimary, size: 24)
                }
            },
            header: {
                Text("Edit Profile")
                    .font(.callout)
                    .fontWeight(.semibold)
            },
            trailingIcon: {
                Button {
                    Task {
                        do {
                            savingLoading = true
                            
                            if viewModel.username != initialUsername {
                                let isUnique = try await UserService.checkUsernameUnique(.init(path: .init(username: viewModel.username)))
                                
                                if isUnique {
                                    try await performEdit()
                                } else {
                                    await MainActor.run {
                                        isUsernameTaken = true
                                    }
                                }
                            } else {
                                try await performEdit()
                            }
                            
                            savingLoading = false
                            hasTriedUsername = true
//                            editUserProfileCoordinator.triggerRefresh.toggle()
                        } catch {
                            savingLoading = false
                            presentToast(Toasts.somethingWentWrong)
                        }
                    }
                } label: {
                    if savingLoading {
                        CliqueProgressView(size: 24)
                    } else {
                        IconImage("check", color: canSave ? .theme.iconPrimary : .theme.iconTertiary, size: 24)
                    }
                }
                .disabled(!canSave)
            }
        )
    }
    
    private func performEdit() async throws {
        let updatedUser = try await viewModel.editUser()
        
        userStore.updateUser(updatedUser, forceUpdateURL: viewModel.pfp != nil)
        
        await MainActor.run {
            dismiss()
        }
    }
    
    @ViewBuilder private func EditRow(title: String, text: Binding<String>, focusField: FocusedField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.footnote.bold())
                    .textSecondary()
                
                if focusField == .bio {
                    Text("\(text.wrappedValue.count) / 120")
                        .textPrimary()
                        .font(.footnote.bold())
                        .maxWidth(.trailing)
                }
            }
            
            HStack {
                TextField(title, text: text, axis: focusField == .bio ? .vertical : .horizontal)
                    .font(.footnote)
                    .focused($focusedField, equals: focusField)
                    .textInputAutocapitalization(focusField.autoCapitalization)
                    .submitLabel(focusField == .bio ? .done : .next)
                    .if(focusField == .bio) { view in
                        view
                            .onEnter($of: text) {
                                focusedField = .none
                            }
                    }
                    .if(focusField == .username) { view in
                        view
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                    }
                    .onSubmit {
                        switch focusField {
                        case .first: focusedField = .last
                        case .last: focusedField = .username
                        case .username: focusedField = .bio
                        case .bio: return // onSubmit doesn't work for vertical textfield
                        }
                    }
                    .onChange(of: text.wrappedValue) {
                        guard focusField == .username else { return }
                        
                        if hasTriedUsername {
                            hasTriedUsername = false
                        }
                        
                        if text.wrappedValue.contains(" ") {
                            text.wrappedValue = text.wrappedValue.replacing(" ", with: "")
                        }
                    }
                    .limitTextField(to: focusField == .bio ? 120 : 50, text: text)
                
                Spacer()
                
                if focusField == .username, !viewModel.username.isEmpty, hasTriedUsername {
                    IconImage(
                        isUsernameTaken ? "x-icon" : "check-circle-empty",
                        color: isUsernameTaken ? .theme.red : .theme.green, size: 20
                    )
                    .animation(.easeInOut, value: isUsernameTaken)
                } else {
                    IconImage("pen", color: .theme.iconSecondary, size: 16)
                        .onTapGesture {
                            focusedField = focusField
                        }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roundCorners(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(Color.theme.strokeSecondary, lineWidth: 1)
            )
        }
    }
}

struct EditProfileRowView: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.bold())
                .textSecondary()
            
            CliqueText(text: title, type: .primary)
        }
    }
}

#Preview {
    EditUserProfileView(user: User.MOCK_USERS[0])
}
