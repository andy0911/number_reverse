import Testing
@testable import Tokaeshi

@MainActor @Suite("広告と自社案内の状態遷移")
struct BannerPresentationTests {
    @Test func refreshFailureAndRecovery() {
        let state = BannerPresentation()
        #expect(!state.showsAd)
        state.receive(); #expect(state.showsAd)
        state.fail("no-fill"); #expect(!state.showsAd); #expect(state.failure == "no-fill")
        // SDK自動更新の次の成功コールバックで復帰する。
        state.receive(); #expect(state.showsAd)
    }
    @Test func invalidatedCallbacksCannotRestoreOldAd() {
        let state = BannerPresentation()
        state.receive(); state.stop()
        state.receive(); state.fail("late callback")
        #expect(state.phase == .stopped)
        #expect(!state.showsAd)
    }
    @Test func retainedViewCanReappearWithoutResurrectingOldCreative() {
        let state = BannerPresentation()
        state.receive(); state.stop(); state.restartIfStopped()
        #expect(state.phase == .loading)
        #expect(!state.showsAd)
        state.receive(); #expect(state.showsAd)
    }
    @Test func ownershipAndRestoreHideEntireSlot() {
        #expect(!BannerVisibility.showsSlot(entitlementsLoaded: false, hasRemovedAds: false))
        #expect(BannerVisibility.showsSlot(entitlementsLoaded: true, hasRemovedAds: false))
        #expect(!BannerVisibility.showsSlot(entitlementsLoaded: true, hasRemovedAds: true))
        #expect(!BannerVisibility.showsSlot(entitlementsLoaded: false, hasRemovedAds: true))
    }
    @Test func metricsNeverTreatPromoOrDemoAsRevenue() {
        let metrics = BannerMetrics()
        metrics.promo(); metrics.impression(isDemo: true); metrics.paid(isDemo: true)
        #expect(metrics.localPromos == 1 && metrics.demoImpressions == 1)
        #expect(metrics.networkImpressions == 0 && metrics.paidEvents == 0)
        metrics.impression(isDemo: false); metrics.paid(isDemo: false)
        #expect(metrics.networkImpressions == 1 && metrics.paidEvents == 1)
        #expect(metrics.localPromos == 1)
    }
}
