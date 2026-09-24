//
//  EmailValidation.swift
//  Gabay
//

import Foundation

extension String {

    // Deliberately loose: the server is the real authority on whether an address exists, this only catches typos worth catching before a round trip, without rejecting an unusual but legal address.
    var isValidEmail: Bool {
        guard !isEmpty, !contains(" "), count <= 254 else { return false }

        let parts = split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1]
        return domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
            && !domain.contains("..")
    }
}
