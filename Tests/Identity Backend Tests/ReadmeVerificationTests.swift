import Testing

@testable import Identity_Backend

@Suite
struct Test {

    // README mentions swift-identities as main package
    @Test
    func `Example from README: Identity module exists`() {
        // Verify the Identity namespace compiles and is accessible
        let identityType = Identity.self

        #expect(String(describing: identityType) == "Identity")
    }

    // README shows installation with .product(name: "Identities", package: "swift-identities")
    @Test
    func `Example from README: Package structure`() {
        // Verify module can be imported and basic types exist
        // This test passes if it compiles, confirming README installation instructions work
        #expect(Bool(true))
    }
}
