import Foundation

/// 広告・課金の合成ルート。`RootView` から 1 つだけ生成し、環境として配る
@MainActor
@Observable
final class Monetization {
    let store: StoreManager
    let ads: AdsManager

    init() {
        store = StoreManager()
        ads = AdsManager(store: store)
    }

    /// アプリ起動時に 1 回呼ぶ
    func start() async {
        await store.start()
        await ads.start()
    }
}
