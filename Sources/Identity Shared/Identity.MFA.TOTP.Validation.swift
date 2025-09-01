import Foundation

extension Identity.MFA.TOTP {
    /// Validates a TOTP code format
    /// - Parameter code: The code to validate
    /// - Returns: true if the code is valid
    public static func isValidCode(_ code: String) -> Bool {
        // Must be numeric and typically 6-8 digits
        let digits = code.count
        guard digits >= 6 && digits <= 8 else { return false }
        
        // Must contain only digits
        return code.allSatisfy { $0.isNumber }
    }
    
    /// Validates a Base32 secret
    /// - Parameter secret: The secret to validate
    /// - Returns: true if the secret is valid Base32
    public static func isValidSecret(_ secret: String) -> Bool {
        // Remove spaces and convert to uppercase
        let cleaned = secret
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "=", with: "") // Remove padding
            .uppercased()
        
        // Check minimum length (10 bytes = 16 Base32 chars without padding)
        guard cleaned.count >= 16 else { return false }
        
        // Check if all characters are valid Base32
        let base32Charset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        let secretCharset = CharacterSet(charactersIn: cleaned)
        
        return secretCharset.isSubset(of: base32Charset)
    }
    
    /// Sanitizes a TOTP code by removing non-numeric characters
    /// - Parameter code: The code to sanitize
    /// - Returns: The sanitized code
    public static func sanitizeCode(_ code: String) -> String {
        return code.filter { $0.isNumber }
    }
    
    /// Sanitizes a Base32 secret by removing invalid characters
    /// - Parameter secret: The secret to sanitize
    /// - Returns: The sanitized secret
    public static func sanitizeSecret(_ secret: String) -> String {
        return secret
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .filter { "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".contains($0) }
    }
}