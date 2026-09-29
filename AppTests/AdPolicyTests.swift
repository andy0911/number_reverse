import Testing
@testable import Tokaeshi

@Suite("広告表示ポリシー spec §11.1")
struct AdPolicyTests {
    let policy = AdPolicy(everyNGames: 3)

    @Test("N 局に 1 回だけ表示する", arguments: [(1, false), (2, false), (3, true), (4, false), (5, false), (6, true)])
    func frequency(count: Int, expected: Bool) {
        #expect(policy.shouldShowAd(finishedGameCount: count, hasRemovedAds: false, adLoaded: true) == expected)
    }

    @Test("購入済みなら回数に関係なく表示しない")
    func purchased() {
        for n in 1...12 {
            #expect(policy.shouldShowAd(finishedGameCount: n, hasRemovedAds: true, adLoaded: true) == false)
        }
    }

    @Test("広告が読み込めていなければ表示しない")
    func notLoaded() {
        #expect(policy.shouldShowAd(finishedGameCount: 3, hasRemovedAds: false, adLoaded: false) == false)
    }

    @Test("対局 0 回では表示しない")
    func zeroGames() {
        #expect(policy.shouldShowAd(finishedGameCount: 0, hasRemovedAds: false, adLoaded: true) == false)
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
