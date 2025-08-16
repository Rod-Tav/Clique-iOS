import Foundation
import SwiftUI

// MARK: - Identifiable Conformance
extension String: @retroactive Identifiable {
    public var id: String { self }
}

extension String {
    func firstLetterCapitalized() -> String {
        guard let first = self.first else { return "" }
        return first.uppercased() + self.dropFirst().lowercased()
    }
    
    func formatPhoneNumber() -> String {
        let cleanNumber = components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        let mask = "(XXX) XXX-XXXX"
        
        var result = ""
        var startIndex = cleanNumber.startIndex
        let endIndex = cleanNumber.endIndex
        
        for char in mask where startIndex < endIndex {
            if char == "X" {
                result.append(cleanNumber[startIndex])
                startIndex = cleanNumber.index(after: startIndex)
            } else {
                result.append(char)
            }
        }
        
        return result
    }
    
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
