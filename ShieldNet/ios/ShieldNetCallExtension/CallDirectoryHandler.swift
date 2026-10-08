import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    private let appGroupSuiteName = "group.com.shieldnet.shieldnet"

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        do {
            try addBlockingPhoneNumbers(to: context)
            try addIdentificationPhoneNumbers(to: context)
        } catch {
            print("ShieldNet Extension Error: \(error.localizedDescription)")
        }

        context.completeRequest()
    }

    private func addBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) throws {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        let rawNumbers = defaults?.array(forKey: "blocked_phone_numbers") as? [Int64] ?? []
        
        // Les numéros doivent obligatoirement être triés par ordre croissant sans doublons pour CallKit
        let sortedUniqueNumbers = Array(Set(rawNumbers)).sorted()

        for number in sortedUniqueNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
    }

    private func addIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) throws {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        let rawNumbers = defaults?.array(forKey: "spam_identification_numbers") as? [Int64] ?? []
        
        let sortedUniqueNumbers = Array(Set(rawNumbers)).sorted()

        for number in sortedUniqueNumbers {
            context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: "ShieldNet: Suspect de Spam")
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        print("ShieldNet CallDirectoryExtension request failed: \(error.localizedDescription)")
    }
}
