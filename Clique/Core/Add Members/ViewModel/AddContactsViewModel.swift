//
//  ContactsViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 2/21/25.
//

import Foundation
import Contacts
import SwiftUI

struct Contact: Identifiable, Equatable {
    let id = UUID()
    let firstName: String
    let lastName: String
    var phoneNumbers: [String] // Change from single `phoneNumber` to an array
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return lhs.firstName == rhs.firstName &&
        lhs.lastName == rhs.lastName &&
        lhs.phoneNumbers == rhs.phoneNumbers
    }
}

@Observable final class AddContactsViewModel {
    var contacts: [Contact] = [] // Store phone numbers
    
    private let contactStore = CNContactStore()
    
    func requestAccess(authType: Binding<String>, presentSettingsAlert: @escaping () -> Void) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            fetchContacts()
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        self.fetchContacts()
                    } else {
                        presentSettingsAlert()
                    }
                }
            }
        case .denied:
            authType.wrappedValue = "Denied"
            presentSettingsAlert()
        case .restricted:
            authType.wrappedValue = "Restricted"
            presentSettingsAlert()
        case .limited:
            DispatchQueue.main.async {
                self.fetchContacts()
            }
            authType.wrappedValue = "Limited"
            presentSettingsAlert()
        @unknown default:
            presentSettingsAlert()
        }
    }
    
    private func fetchContacts() {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        DispatchQueue.global(qos: .userInitiated).async {
            var contactsDict: [String: Contact] = [:] // Dictionary to group contacts by name
            
            do {
                try self.contactStore.enumerateContacts(with: request) { contact, _ in
                    let fullName = "\(contact.givenName) \(contact.familyName)"
                    let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
                    
                    if var existingContact = contactsDict[fullName] {
                        // Merge phone numbers if contact already exists
                        existingContact.phoneNumbers.append(contentsOf: phoneNumbers)
                        contactsDict[fullName] = existingContact
                    } else {
                        // Create new contact entry
                        contactsDict[fullName] = Contact(
                            firstName: contact.givenName,
                            lastName: contact.familyName,
                            phoneNumbers: phoneNumbers
                        )
                    }
                }
                
                DispatchQueue.main.async {
                    self.contacts = Array(contactsDict.values) // Convert dictionary back to an array
                }
            } catch {
                print("Failed to fetch contacts: \(error)")
            }
        }
    }
}
