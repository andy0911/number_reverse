import Foundation
import ObjectiveC.runtime
import Testing

@Suite("Unity mediation static linkage")
struct UnityAdapterLinkageTests {
    @Test("Unity server configuration category is linked into the app")
    func serverConfigurationCategoryIsPresent() throws {
        let configurationClass = try #require(NSClassFromString("GADMediationServerConfiguration"))
        // Inspect only: do not invoke adapter internals or request an advertisement.
        #expect(class_getInstanceMethod(configurationClass, NSSelectorFromString("gameIds")) != nil)
    }
}
