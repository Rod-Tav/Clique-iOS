//
//  AddContactsView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/21/25.
//

import SwiftUI
import Toasts
import PhoneNumberKit
import MessageUI

struct AddContactsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var viewModel = AddContactsViewModel()
    
    @State private var showSettingsAlert: Bool = false
    @State private var authType: String = "Denied"
    
    @State private var contactsOnClique: [User] = []
    @State private var contactsNotOnClique: [Contact] = []
    
    @State private var selectedNumberForInvite: String?
    @State private var showMessageComposer = false
    
    @State private var scrollID: String?
    
    @State private var searchText: String = ""
    @FocusState private var searchIsFocused: Bool
    
    var alignment: HorizontalAlignment = .center
    var fromAuth: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: alignment, spacing: 16) {
                VStack(spacing: 8) {
                    Text("Find your friends")
                        .textPrimary()
                        .font(.largeTitle.bold())
                        .kerning(0.1292)
                    
                    Text("Clique is way more fun with friends.")
                        .font(.body)
                        .textSecondary()
                }
                
                SearchBar(searchText: $searchText, isSearchFocused: $searchIsFocused)
                    .onSimultaneousTap {
                        scrollID = "TOP"
                    }
            }
            
            if !(contactsOnClique.isEmpty && contactsNotOnClique.isEmpty) {
                ScrollView {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.clear)
                            .frame(1)
                            .id("TOP")
                        
                        LazyVStack(spacing: 24) {
                            // for scroll to top
                            
                            // Show contacts already on Clique
                            if !contactsOnClique.isEmpty {
                                VStack(spacing: 8) {
                                    TextDivider("Contacts on Clique")
                                    
                                    LazyVStack(spacing: 16) {
                                        ForEach(contactsOnClique.filter { user in
                                            searchText.isEmpty || user.fullname.localizedCaseInsensitiveContains(searchText)
                                        }) { user in
                                            Button {
                                                if !fromAuth {
                                                    dismiss()
                                                    tabViewCoordinator.navigate(to: user)
                                                }
                                            } label: {
                                                UserCellWithFollow(uid: user.id)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Show contacts NOT on Clique
                            if !contactsNotOnClique.isEmpty {
                                VStack(spacing: 8) {
                                    TextDivider("Invite your contacts")
                                    
                                    LazyVStack(spacing: 16) {
                                        ForEach(contactsNotOnClique.filter { contact in
                                            searchText.isEmpty || "\(contact.firstName) \(contact.lastName)".localizedCaseInsensitiveContains(searchText)
                                        }, id: \.id) { contact in
                                            HStack(spacing: 8) {
                                                Image("default-gradient")
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(48)
                                                    .clipShape(.circle)
                                                
                                                Text("\(contact.firstName) \(contact.lastName)")
                                                    .font(.footnote.bold())
                                                    .textPrimary()
                                                
                                                Spacer()
                                                
                                                SmallCTA(
                                                    type: .primary,
                                                    leadingIcon: "plus",
                                                    text: "Invite") {
                                                        print("Invite button tapped for contact: \(contact.firstName) \(contact.lastName)")
                                                        guard MFMessageComposeViewController.canSendText() else {
                                                            print("Device cannot send text messages.")
                                                            presentToast(Toasts.deviceCantMessage)
                                                            return
                                                        }
                                                        guard let firstNumber = contact.phoneNumbers.first else { return }
                                                        print("Using phone number: \(firstNumber)")
                                                        selectedNumberForInvite = firstNumber
                                                        showMessageComposer = true
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollTo(id: $scrollID)
                .scrollBarIgnorePadding(16)
            }
        }
        .maxWidth(.leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear {
            viewModel.requestAccess(authType: $authType) {
                if !fromAuth { // TODO: figure out why when going to settings and coming back it takes them into main tab view. this skips welcome screen which is where notifications are set and we can't have that
                    showSettingsAlert = true
                }
            }
        }
        .alert("Contact Access \(authType)", isPresented: $showSettingsAlert) {
            Button("Go to Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("Clique needs access to your contacts to find your friends.")
        }
        .onChange(of: viewModel.contacts, initial: true) {
            guard !viewModel.contacts.isEmpty else { return }
            fetchUsersOnClique()
        }
        .sheet(isPresented: $showMessageComposer) {
            if let number = selectedNumberForInvite {
                MessageComposer(
                    recipients: [number],
                    body: "Hey! Join me on Clique: https://apps.apple.com/us/app/clique-group-social/id6742713460"
                )
                .onAppear {
                    print("Presenting MessageComposer for: \(number)")
                }
            }
        }
    }
    
    /// Fetch users on Clique based on phone numbers
    /// Fetch users on Clique based on phone numbers
    private func fetchUsersOnClique() {
        Task {
            do {
                let phoneNumberKit = PhoneNumberUtility()
                var phoneNumbers: [String] = []
                var contactMap: [String: Contact] = [:] // Key: contact ID or name, Value: Contact
                
                for contact in viewModel.contacts {
                    for number in contact.phoneNumbers {
                        do {
                            let parsedNumber = try phoneNumberKit.parse(number)
                            let formattedNumber = "+1" + phoneNumberKit.format(parsedNumber, toType: .national)
                            phoneNumbers.append(formattedNumber)
                            
                            // Ensure only the first appearance of a contact is stored
                            let contactKey = "\(contact.firstName) \(contact.lastName)"
                            if contactMap[contactKey] == nil {
                                contactMap[contactKey] = contact
                            }
                        } catch {
                            continue
                        }
                    }
                }
                
                let usersOnClique = try await UserService.getUsersByNumbers(
                    .init(body: .json(.init(phoneNumbers: phoneNumbers)))
                )
                
                contactsOnClique = usersOnClique
                
                let cliquePhoneNumbers = Set(usersOnClique.map { $0.number })
                
                contactsNotOnClique = contactMap.values.filter { contact in
                    contact.phoneNumbers.contains { number in
                        guard let parsedNumber = try? phoneNumberKit.parse(number) else { return false }
                        let formattedString = phoneNumberKit.format(parsedNumber, toType: .e164)
                        return !cliquePhoneNumbers.contains(formattedString)
                    }
                }
                
                userStore.updateUsers(usersOnClique)
            } catch {
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
}

#Preview {
    AddContactsView()
        .environment(TabViewCoordinator())
        .environment(UserStore())
}


struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposer
        init(_ parent: MessageComposer) { self.parent = parent }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}
