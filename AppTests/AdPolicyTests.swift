import Foundation
import Testing
@testable import Tokaeshi

@Suite("広告表示ポリシー spec §11.1")
struct AdPolicyTests {
    let policy = AdPolicy.default
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("前回表示から180秒以上で表示する", arguments: [-1.0, 0, 179, 179.999, 180, 181, 360])
    func interval(elapsed: TimeInterval) {
        #expect(policy.shouldShowAd(finishedGameCount: 2, hasRemovedAds: false, adLoaded: true,
                                   lastShownAt: now.addingTimeInterval(-elapsed), now: now) == (elapsed >= 180))
    }

    @Test("未表示なら2局目以降は局数によらず表示候補", arguments: [2, 3, 4, 5, 6, 12])
    func neverShown(count: Int) {
        #expect(policy.shouldShowAd(finishedGameCount: count, hasRemovedAds: false, adLoaded: true,
                                   lastShownAt: nil, now: now))
    }

    @Test("初回と不正な対局数では常に表示しない", arguments: [-1, 0, 1])
    func firstGame(count: Int) {
        for lastShownAt: Date? in [nil, now.addingTimeInterval(-360)] {
            #expect(!policy.shouldShowAd(finishedGameCount: count, hasRemovedAds: false, adLoaded: true,
                                        lastShownAt: lastShownAt, now: now))
        }
    }

    @Test("購入済みまたは未ロードなら時間が経過していても表示しない")
    func unavailable() {
        for lastShownAt: Date? in [nil, now.addingTimeInterval(-360)] {
            #expect(!policy.shouldShowAd(finishedGameCount: 3, hasRemovedAds: true, adLoaded: true,
                                        lastShownAt: lastShownAt, now: now))
            #expect(!policy.shouldShowAd(finishedGameCount: 3, hasRemovedAds: false, adLoaded: false,
                                        lastShownAt: lastShownAt, now: now))
        }
    }

}

@Suite("広告カウント対象の判定 spec §11.1")
struct AdTriggerTests {
    @Test("cpuOnly（動作確認用）はカウント対象外")
    func cpuOnlyExcluded() {
        let t = AdTrigger(mode: .cpuOnly, isMidGameExit: false, didReachFinished: true)
        #expect(t.isCountable == false)
    }

    @Test("対局途中の離脱はカウント対象外")
    func midGameExitExcluded() {
        let t = AdTrigger(mode: .twoPlayers, isMidGameExit: true, didReachFinished: false)
        #expect(t.isCountable == false)
    }

    @Test("2人対戦・CPU対戦で終了まで進んだ場合のみカウント対象")
    func countableCases() {
        #expect(AdTrigger(mode: .twoPlayers, isMidGameExit: false, didReachFinished: true).isCountable)
        #expect(AdTrigger(mode: .vsCPU, isMidGameExit: false, didReachFinished: true).isCountable)
    }
}
