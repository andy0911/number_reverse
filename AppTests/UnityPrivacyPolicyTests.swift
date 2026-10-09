import Testing
@testable import Tokaeshi

@Suite("Unity同意の安全な伝播")
struct UnityPrivacyPolicyTests {
    @Test("明示同意、GDPR非対象、ATT許可が揃う場合のみ許可")
    func consentMatrix() {
        for explicit in [false, true] {
            for gdpr: Int? in [nil, 0, 1, 2] {
                for att in [false, true] {
                    let result = UnityPrivacyPolicy.permitsPersonalization(
                        explicitlyAllowed: explicit, gdprApplies: gdpr, trackingAuthorized: att)
                    #expect(result == (explicit && gdpr == 0 && att))
                }
            }
        }
    }
}
