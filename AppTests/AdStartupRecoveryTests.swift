import Foundation
import Testing
@testable import Tokaeshi

@MainActor @Suite("広告起動の通信失敗からの復帰")
struct AdStartupRecoveryTests {
    enum Offline: Error { case unavailable }
    @Test func cachedUMPDecisionSurvivesUpdateError() async {
        let allowed = await AdConsentReadiness.resolve(update: { throw Offline.unavailable }, canRequest: { true })
        #expect(allowed.canRequestAds && allowed.failed)
        let denied = await AdConsentReadiness.resolve(update: { throw Offline.unavailable }, canRequest: { false })
        #expect(!denied.canRequestAds && denied.failed)
    }
    @Test func successfulFormStillRequiresUMPAuthorization() async {
        let denied = await AdConsentReadiness.resolve(update: {}, canRequest: { false })
        #expect(!denied.canRequestAds && !denied.failed)
    }
    @Test func foregroundDoesNotBypassCooldownOrDuplicateWork() {
        var recovery = AdStartupRecovery()
        let now = Date(timeIntervalSince1970: 1_000)
        let result1 = recovery.begin(at: now)
        #expect(result1)
        let result2 = !recovery.begin(at: now)
        #expect(result2)
        recovery.failed(at: now)
        let result3 = !recovery.begin(at: now.addingTimeInterval(29))
        #expect(result3)
        let result4 = recovery.begin(at: now.addingTimeInterval(30))
        #expect(result4)
        recovery.failed(at: now.addingTimeInterval(30))
        let result5 = !recovery.begin(at: now.addingTimeInterval(89))
        #expect(result5)
        let result6 = recovery.begin(at: now.addingTimeInterval(90))
        #expect(result6)
        recovery.succeeded()
        let result7 = !recovery.begin(at: now.addingTimeInterval(999))
        #expect(result7)
    }
    @Test func longOutageUsesBoundedBackoff() {
        var recovery = AdStartupRecovery()
        var now = Date(timeIntervalSince1970: 1_000)
        for delay in [30.0, 60, 120, 240, 300, 300] {
            let result8 = recovery.begin(at: now)
            #expect(result8)
            recovery.failed(at: now)
            #expect(recovery.retryAt == now.addingTimeInterval(delay))
            now = now.addingTimeInterval(delay)
        }
    }
}
