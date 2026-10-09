#if MEDIATION_QA
import Foundation
import Testing
@testable import Tokaeshi

@Suite("同意変更で古い広告を無効化", .serialized)
@MainActor
struct AdsPrivacyTransitionTests {
    @Test("許可後の撤回は保存値を更新し広告世代を進め、QA通常広告を停止維持")
    func revokeConsent() async {
        let key = "ads.unityPersonalizationAllowed"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        let ads = AdsManager(store: StoreManager())
        let initial = ads.adGeneration
        await ads.setUnityPersonalizationAllowed(true)
        #expect(ads.adGeneration == initial + 1)
        await ads.setUnityPersonalizationAllowed(false)
        #expect(ads.adGeneration == initial + 2)
        #expect(!ads.unityPersonalizationAllowed)
        #expect(!UserDefaults.standard.bool(forKey: key))
        #expect(!ads.canRequestAds)
        #expect(!ads.isUpdatingPrivacy)
        #expect(!AdsManager(store: StoreManager()).unityPersonalizationAllowed)
    }
}
#endif
