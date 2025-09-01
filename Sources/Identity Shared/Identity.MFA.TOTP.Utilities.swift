import Foundation

extension Identity.MFA.TOTP {
    /// Format a Base32 secret for manual entry
    /// Groups characters in blocks of 4 for easier entry
    public static func formatManualEntryKey(_ secret: String) -> String {
        let cleaned = secret
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "=", with: "") // Remove padding
            .uppercased()
        
        var formatted = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(char)
        }
        return formatted
    }
}