import AppKit
import Contacts
import Foundation
import JfredCore

/// Reads the local Address Book through Contacts.framework. The app only keeps
/// the display fields used by the launcher; the system-owned record identifier
/// is retained so opening a contact lands on the right person.
enum ContactsIndex {
    static func load(requestAccess: Bool = false) async -> [ContactRecord] {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined, requestAccess {
            let granted = await askForAccess(store)
            guard granted else { return [] }
        } else if status != .authorized {
            return []
        }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName
        request.mutableObjects = false

        var records: [ContactRecord] = []
        do {
            try store.enumerateContacts(with: request) { contact, stop in
                if records.count >= 5_000 { stop.pointee = true; return }
                let name = displayName(contact)
                guard !name.isEmpty else { return }
                let email = contact.emailAddresses.first?.value as String? ?? ""
                let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                records.append(ContactRecord(
                    id: contact.identifier,
                    name: name,
                    email: email,
                    phone: phone,
                    uid: contact.identifier,
                    jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
                    organization: contact.organizationName.isEmpty ? nil : contact.organizationName
                ))
            }
        } catch {
            return []
        }
        return records.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func askForAccess(_ store: CNContactStore) async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func displayName(_ contact: CNContact) -> String {
        if !contact.nickname.isEmpty { return contact.nickname }
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        if let formatted = formatter.string(from: contact), !formatted.isEmpty { return formatted }
        let parts = [contact.givenName, contact.middleName, contact.familyName].filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return contact.organizationName
    }
}
