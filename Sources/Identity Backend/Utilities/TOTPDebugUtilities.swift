import Foundation
import Dependencies

extension Identity.MFA.TOTP {
    /// Check if a code is the debug bypass code
    /// Only available in DEBUG builds for testing
    package static func isDebugBypassCode(_ code: String) -> Bool {
        #if DEBUG
        return code == "000000"
        #else
        return false
        #endif
    }
    
    /// Log when debug bypass is used
    package static func logDebugBypass() {
        #if DEBUG
        @Dependency(\.logger) var logger
        logger.warning("BYPASS: Accepting test code for debugging")
        #endif
    }
}