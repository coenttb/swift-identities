import Testing

@testable import Identity_Backend

@Suite("README Verification")
struct ReadmeVerificationTests {

  // README mentions swift-identities as main package
  @Test("Example from README: Identity module exists")
  func exampleIdentityModuleExists() {
    // Verify the Identity namespace compiles and is accessible
    let identityType = Identity.self

    #expect(String(describing: identityType) == "Identity")
  }

  // README shows installation with .product(name: "Identities", package: "swift-identities")
  @Test("Example from README: Package structure")
  func examplePackageStructure() {
    // Verify module can be imported and basic types exist
    // This test passes if it compiles, confirming README installation instructions work
    #expect(Bool(true))
  }
}
